import { api } from '../../api';
import { IDashboardRepository } from '../../domain/repositories/IDashboardRepository';

export class DashboardRepositoryImpl extends IDashboardRepository {
  async fetchAlerts() {
    try {
      return await api.getAlerts();
    } catch (e) {
      console.error("Failed to fetch alerts from network", e);
      return [];
    }
  }

  async fetchReports() {
    try {
      return await api.getReports();
    } catch (e) {
      console.error("Failed to fetch reports from network", e);
      return [];
    }
  }
}
