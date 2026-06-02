import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1';

export const api = {
  // SOS Alerts
  getAlerts: async () => {
    const res = await axios.get(`${API_BASE}/sos/alerts?limit=100`);
    return res.data.alerts;
  },
  resolveAlert: async (id) => {
    const res = await axios.patch(`${API_BASE}/sos/alerts/${id}/resolve`);
    return res.data;
  },
  
  // Accident Reports
  getReports: async () => {
    const res = await axios.get(`${API_BASE}/accident/reports?limit=100`);
    return res.data.reports;
  },
  getReportDetails: async (id) => {
    const res = await axios.get(`${API_BASE}/accident/reports/${id}`);
    return res.data;
  },
  updateReportStatus: async (id, status) => {
    const res = await axios.patch(`${API_BASE}/accident/reports/${id}/status`, { status });
    return res.data;
  }
};
