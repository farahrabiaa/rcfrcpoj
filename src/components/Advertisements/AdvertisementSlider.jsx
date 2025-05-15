import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { supabase } from '../../lib/supabase';

export default function AdvertisementSlider({ position = 'home', className = '' }) {
  const [ads, setAds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [currentIndex, setCurrentIndex] = useState(0);

  useEffect(() => {
    fetchAds();
  }, [position]);

  const fetchAds = async () => {
    try {
      setLoading(true);
      
      // Get current date in ISO format
      const today = new Date().toISOString().split('T')[0];
      
      // Fetch active slider ads for the specified position
      const { data, error } = await supabase
        .from('advertisements')
        .select(`
          *,
          vendor:vendor_id(store_name)
        `)
        .eq('type', 'slider')
        .eq('position', position)
        .eq('status', 'active')
        .lte('start_date', today)
        .gte('end_date', today)
        .order('priority', { ascending: true });
      
      if (error) throw error;
      
      setAds(data || []);
    } catch (error) {
      console.error('Error fetching advertisements:', error);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    // Record view for the current ad
    if (ads.length > 0 && ads[currentIndex]?.id) {
      incrementAdView(ads[currentIndex].id);
    }
  }, [currentIndex, ads]);

  useEffect(() => {
    // Auto-rotate ads every 5 seconds
    if (ads.length <= 1) return;

    const interval = setInterval(() => {
      setCurrentIndex(prevIndex => (prevIndex + 1) % ads.length);
    }, 5000);

    return () => clearInterval(interval);
  }, [ads.length]);

  const incrementAdView = async (adId) => {
    try {
      // Use RPC function to increment views
      await supabase.rpc('increment_advertisement_views', { p_ad_id: adId });
    } catch (error) {
      console.error('Error recording advertisement view:', error);
    }
  };

  const handleClick = async (adId) => {
    // Record click when the ad is clicked
    if (adId) {
      try {
        await supabase.rpc('increment_advertisement_clicks', { p_ad_id: adId });
      } catch (error) {
        console.error('Error recording advertisement click:', error);
      }
    }
  };

  const goToSlide = (index) => {
    setCurrentIndex(index);
  };

  if (loading) {
    return (
      <div className={`animate-pulse bg-gray-200 rounded-lg ${className}`} style={{ aspectRatio: '16/5' }}></div>
    );
  }

  if (ads.length === 0) {
    return null;
  }

  const currentAd = ads[currentIndex];

  return (
    <div className={`relative overflow-hidden rounded-lg ${className}`}>
      {/* Main slider */}
      <div className="relative" style={{ aspectRatio: '16/5' }}>
        {currentAd.link ? (
          <Link to={currentAd.link} onClick={() => handleClick(currentAd.id)}>
            <img 
              src={currentAd.image_url} 
              alt={currentAd.title}
              className="w-full h-full object-cover"
              onError={(e) => {
                e.target.onerror = null;
                e.target.src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20width%3D%22800%22%20height%3D%22250%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Crect%20width%3D%22800%22%20height%3D%22250%22%20fill%3D%22%23e2e8f0%22%3E%3C%2Frect%3E%3Ctext%20x%3D%22400%22%20y%3D%22125%22%20font-size%3D%2230%22%20text-anchor%3D%22middle%22%20alignment-baseline%3D%22middle%22%20font-family%3D%22Arial%2C%20sans-serif%22%20fill%3D%22%2364748b%22%3E%D8%A5%D8%B9%D9%84%D8%A7%D9%86%3C%2Ftext%3E%3C%2Fsvg%3E';
              }}
            />
          </Link>
        ) : (
          <img 
            src={currentAd.image_url} 
            alt={currentAd.title}
            className="w-full h-full object-cover"
            onError={(e) => {
              e.target.onerror = null;
              e.target.src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20width%3D%22800%22%20height%3D%22250%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Crect%20width%3D%22800%22%20height%3D%22250%22%20fill%3D%22%23e2e8f0%22%3E%3C%2Frect%3E%3Ctext%20x%3D%22400%22%20y%3D%22125%22%20font-size%3D%2230%22%20text-anchor%3D%22middle%22%20alignment-baseline%3D%22middle%22%20font-family%3D%22Arial%2C%20sans-serif%22%20fill%3D%22%2364748b%22%3E%D8%A5%D8%B9%D9%84%D8%A7%D9%86%3C%2Ftext%3E%3C%2Fsvg%3E';
            }}
          />
        )}
        
        <div className="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent flex flex-col justify-end p-6">
          <h3 className="text-white text-2xl font-bold">{currentAd.title}</h3>
          {currentAd.description && (
            <p className="text-white/90 text-lg mt-2">{currentAd.description}</p>
          )}
        </div>
        
        {currentAd.vendor?.store_name && (
          <div className="absolute top-4 left-4 bg-white/80 px-3 py-1 rounded-full text-sm">
            {currentAd.vendor.store_name}
          </div>
        )}
      </div>
      
      {/* Navigation dots */}
      {ads.length > 1 && (
        <div className="absolute bottom-4 left-0 right-0 flex justify-center space-x-2">
          {ads.map((_, index) => (
            <button
              key={index}
              onClick={() => goToSlide(index)}
              className={`w-3 h-3 rounded-full ${
                index === currentIndex ? 'bg-white' : 'bg-white/50'
              }`}
              aria-label={`Go to slide ${index + 1}`}
            />
          ))}
        </div>
      )}
      
      {/* Navigation arrows */}
      {ads.length > 1 && (
        <>
          <button
            onClick={() => setCurrentIndex((currentIndex - 1 + ads.length) % ads.length)}
            className="absolute top-1/2 right-4 -translate-y-1/2 bg-black/30 hover:bg-black/50 text-white p-2 rounded-full"
            aria-label="Previous slide"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
            </svg>
          </button>
          <button
            onClick={() => setCurrentIndex((currentIndex + 1) % ads.length)}
            className="absolute top-1/2 left-4 -translate-y-1/2 bg-black/30 hover:bg-black/50 text-white p-2 rounded-full"
            aria-label="Next slide"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </>
      )}
    </div>
  );
}