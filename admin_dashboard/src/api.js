import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1';

// Create a centralized Axios instance
const apiClient = axios.create({
  baseURL: API_BASE,
  timeout: 10000, // 10-second timeout to prevent UI hanging
  headers: {
    'Content-Type': 'application/json',
  },
});

// Finding #10: Add auth token to all outgoing requests
apiClient.interceptors.request.use((config) => {
  const token = sessionStorage.getItem('admin_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// Centralized error interceptor with auth redirect
apiClient.interceptors.response.use(
  (response) => response,
  (error) => {
    // Finding #10: Auto-logout on 401 — token expired or invalid
    if (error.response?.status === 401) {
      sessionStorage.removeItem('admin_token');
      window.location.reload(); // Force re-render to show login screen
    }
    console.error('[API Error]:', error.response?.data?.detail || error.message);
    return Promise.reject(error);
  }
);

export const api = {
  // SOS Alerts
  getAlerts: async () => {
    try {
      const res = await apiClient.get('/sos/alerts', { params: { limit: 100 } });
      return res.data?.alerts || [];
    } catch (error) {
      throw new Error('Failed to fetch SOS alerts');
    }
  },
  resolveAlert: async (id) => {
    try {
      const res = await apiClient.patch(`/sos/alerts/${id}/resolve`);
      return res.data;
    } catch (error) {
      throw new Error(`Failed to resolve SOS alert #${id}`);
    }
  },
  
  // Accident Reports
  getReports: async () => {
    try {
      const res = await apiClient.get('/accident/reports', { params: { limit: 100 } });
      return res.data?.reports || [];
    } catch (error) {
      throw new Error('Failed to fetch accident reports');
    }
  },
  getReportDetails: async (id) => {
    try {
      const res = await apiClient.get(`/accident/reports/${id}`);
      return res.data;
    } catch (error) {
      throw new Error(`Failed to fetch details for report #${id}`);
    }
  },
  updateReportStatus: async (id, status) => {
    try {
      const res = await apiClient.patch(`/accident/reports/${id}/status`, { status });
      return res.data;
    } catch (error) {
      throw new Error(`Failed to update status for report #${id}`);
    }
  }
};
