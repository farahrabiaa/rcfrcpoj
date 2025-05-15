import { useState, useCallback } from 'react';

export default function useFilters(initialFilters = {}, data = []) {
  const [filters, setFilters] = useState(initialFilters);

  const filterData = useCallback((items) => {
    return items.filter(item => {
      return Object.entries(filters).every(([key, filter]) => {
        if (!filter.value && filter.value !== 0) return true;

        switch (filter.type) {
          case 'text':
            const itemValue = String(item[key] || '');
            const filterValue = String(filter.value || '');
            return itemValue.toLowerCase().includes(filterValue.toLowerCase());
          
          case 'select':
            return filter.value === '' || item[key] === filter.value;
          
          case 'number':
            return item[key] === Number(filter.value);
          
          case 'date':
            const itemDate = new Date(item[key]).toISOString().split('T')[0];
            return itemDate === filter.value;
          
          case 'dateRange':
            const date = new Date(item[key]);
            const start = filter.value.start ? new Date(filter.value.start) : null;
            const end = filter.value.end ? new Date(filter.value.end) : null;
            
            if (start && end) {
              return date >= start && date <= end;
            } else if (start) {
              return date >= start;
            } else if (end) {
              return date <= end;
            }
            return true;
          
          default:
            return true;
        }
      });
    });
  }, [filters]);

  const handleFilterChange = useCallback((newFilters) => {
    setFilters(prevFilters => ({
      ...prevFilters,
      ...Object.fromEntries(
        Object.entries(newFilters).map(([key, value]) => [
          key,
          { ...prevFilters[key], value }
        ])
      )
    }));
  }, []);

  const resetFilters = useCallback(() => {
    setFilters(initialFilters);
  }, [initialFilters]);

  return {
    filters,
    filterData,
    handleFilterChange,
    resetFilters
  };
}