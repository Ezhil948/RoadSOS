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
      setData(result);
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
