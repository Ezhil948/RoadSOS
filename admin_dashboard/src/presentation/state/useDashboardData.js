import { useState, useEffect, useCallback } from 'react';
import { DashboardRepositoryImpl } from '../../data/repositories/DashboardRepositoryImpl';
import { FetchDashboardDataUseCase } from '../../domain/use_cases/FetchDashboardDataUseCase';

// Inject Dependencies (In a real app, this could be provided via React Context)
const repository = new DashboardRepositoryImpl();
const fetchUseCase = new FetchDashboardDataUseCase(repository);

export function useDashboardData(pollingIntervalMs = 10000) {
  const [data, setData] = useState({
    activeSos: [],
    pastSos: [],
    activeReports: [],
    pastReports: []
  });
  
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  const refreshData = useCallback(async () => {
    try {
      const result = await fetchUseCase.execute();
      // Finding #22: Only update state if data actually changed — prevents unnecessary re-renders
      setData(prev => {
        const prevStr = JSON.stringify(prev);
        const newStr = JSON.stringify(result);
        if (prevStr === newStr) return prev; // Same reference = no re-render
        return result;
      });
      setError(null);
    } catch (e) {
      setError(e.message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    refreshData();
    const interval = setInterval(refreshData, pollingIntervalMs);
    return () => clearInterval(interval);
  }, [refreshData, pollingIntervalMs]);

  return {
    ...data,
    isLoading,
    error,
    refreshData
  };
}
