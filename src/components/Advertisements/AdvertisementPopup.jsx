import React, { useState, useEffect } from 'react';
import { Dialog } from '@headlessui/react';
import { Link } from 'react-router-dom';
import { supabase } from '../../lib/supabase';

export default function AdvertisementPopup({ position = 'home' }) {
  const [ad, setAd] = useState(null);
  const [isOpen, setIsOpen] = useState(false);
  const [hasShown, setHasShown] = useState(false);

  useEffect(() => {
    // Check if we've already shown a popup in this session
    const popupShown = sessionStorage.getItem('popupShown');
    if (popupShown) {
      setHasShown(true);
      return;
    }

    const fetchAd = async () => {
      try {
        // Get current date in ISO format
        const today = new Date().toISOString().split('T')[0];
        
        // Fetch active popup ads for the specified position
        const { data, error } = await supabase
          .from('advertisements')
          .select(`
            *,
            vendor:vendor_id(store_name)
          `)
          .eq('type', 'popup')
          .eq('position', position)
          .eq('status', 'active')
          .lte('start_date', today)
          .gte('end_date', today)
          .order('priority', { ascending: true });
        
        if (error) throw error;
        
        if (data && data.length > 0) {
          // Get the highest priority popup
          const popup = data[0];
          setAd(popup);
          
          // Show popup after a delay
          setTimeout(() => {
            setIsOpen(true);
            // Record view
            incrementAdView(popup.id);
            // Mark as shown in this session
            sessionStorage.setItem('popupShown', 'true');
            setHasShown(true);
          }, 3000);
        }
      } catch (error) {
        console.error('Error fetching advertisement popup:', error);
      }
    };

    if (!hasShown) {
      fetchAd();
    }
  }, [position, hasShown]);

  const incrementAdView = async (adId) => {
    try {
      // Use RPC function to increment views
      await supabase.rpc('increment_advertisement_views', { p_ad_id: adId });
    } catch (error) {
      console.error('Error recording advertisement view:', error);
    }
  };

  const handleClick = async () => {
    // Record click when the ad is clicked
    if (ad?.id) {
      try {
        await supabase.rpc('increment_advertisement_clicks', { p_ad_id: ad.id });
      } catch (error) {
        console.error('Error recording advertisement click:', error);
      }
    }
    setIsOpen(false);
  };

  if (!ad) return null;

  return (
    <Dialog
      open={isOpen}
      onClose={() => setIsOpen(false)}
      className="fixed inset-0 z-50 overflow-y-auto"
    >
      <div className="flex items-center justify-center min-h-screen">
        <Dialog.Overlay className="fixed inset-0 bg-black opacity-50" />

        <div className="relative bg-white rounded-lg shadow-xl max-w-md w-full mx-4 overflow-hidden">
          <button
            onClick={() => setIsOpen(false)}
            className="absolute top-2 right-2 bg-white/80 p-1 rounded-full z-10"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>

          <div className="relative">
            {ad.link ? (
              <Link to={ad.link} onClick={handleClick}>
                <img
                  src={ad.image_url}
                  alt={ad.title}
                  className="max-h-48 mx-auto rounded"
                  onError={(e) => {
                    e.target.onerror = null;
                    e.target.src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20width%3D%22400%22%20height%3D%22300%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Crect%20width%3D%22400%22%20height%3D%22300%22%20fill%3D%22%23e2e8f0%22%3E%3C%2Frect%3E%3Ctext%20x%3D%22200%22%20y%3D%22150%22%20font-size%3D%2220%22%20text-anchor%3D%22middle%22%20alignment-baseline%3D%22middle%22%20font-family%3D%22Arial%2C%20sans-serif%22%20fill%3D%22%2364748b%22%3E%D8%A5%D8%B9%D9%84%D8%A7%D9%86%3C%2Ftext%3E%3C%2Fsvg%3E';
                  }}
                />
              </Link>
            ) : (
              <img
                src={ad.image_url}
                alt={ad.title}
                className="max-h-48 mx-auto rounded"
                onError={(e) => {
                  e.target.onerror = null;
                  e.target.src = 'data:image/svg+xml;charset=UTF-8,%3Csvg%20width%3D%22400%22%20height%3D%22300%22%20xmlns%3D%22http%3A%2F%2Fwww.w3.org%2F2000%2Fsvg%22%3E%3Crect%20width%3D%22400%22%20height%3D%22300%22%20fill%3D%22%23e2e8f0%22%3E%3C%2Frect%3E%3Ctext%20x%3D%22200%22%20y%3D%22150%22%20font-size%3D%2220%22%20text-anchor%3D%22middle%22%20alignment-baseline%3D%22middle%22%20font-family%3D%22Arial%2C%20sans-serif%22%20fill%3D%22%2364748b%22%3E%D8%A5%D8%B9%D9%84%D8%A7%D9%86%3C%2Ftext%3E%3C%2Fsvg%3E';
                }}
              />
            )}
          </div>

          <div className="p-4">
            <h3 className="text-xl font-bold">{ad.title}</h3>
            {ad.description && (
              <p className="mt-2 text-gray-600">{ad.description}</p>
            )}
            
            {ad.link && (
              <div className="mt-4 flex justify-center">
                <Link
                  to={ad.link}
                  onClick={handleClick}
                  className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                >
                  عرض التفاصيل
                </Link>
              </div>
            )}
            
            {ad.vendor?.store_name && (
              <div className="mt-4 text-sm text-gray-500 text-center">
                {ad.vendor.store_name}
              </div>
            )}
          </div>
        </div>
      </div>
    </Dialog>
  );
}