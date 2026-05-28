import React, { useState, useEffect } from 'react';
import { formatDistanceToNow } from 'date-fns';
import { ShieldAlert, Car, MapPin, Clock, CheckCircle, Activity, User, Info } from 'lucide-react';
import { api } from './api';
import './index.css';

// --- Components ---

const Badge = ({ type, children }) => (
  <span className={`badge ${type}`}>{children}</span>
);

const Card = ({ item, type, onClick }) => {
  const isSOS = type === 'sos';
  const status = item.status;
  const severity = item.severity;
  const time = new Date(isSOS ? item.alerted_at : item.reported_at);

  return (
    <div className="incident-card fade-in" onClick={() => onClick(item, type)}>
      <div className="incident-header">
        <span className="incident-id">#{item.id} • {isSOS ? 'SOS ALERT' : 'ACCIDENT REPORT'}</span>
        <Badge type={isSOS ? (status === 'active' ? 'active' : 'resolved') : status}>
          {status}
        </Badge>
      </div>
      
      <div className="incident-body">
        {isSOS ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--accent-red)' }}>
            <Activity size={18} /> Emergency Triggered
          </div>
        ) : (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Car size={18} /> Accident Reported ({severity})
          </div>
        )}
      </div>

      <div className="incident-footer">
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <MapPin size={14} /> {item.lat.toFixed(4)}, {item.lng.toFixed(4)}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Clock size={14} /> {formatDistanceToNow(time, { addSuffix: true })}
        </div>
      </div>
    </div>
  );
};

const IncidentModal = ({ incident, type, onClose, onStatusChange }) => {
  const [details, setDetails] = useState(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (type === 'report') {
      setLoading(true);
      api.getReportDetails(incident.id)
        .then(data => setDetails(data))
        .finally(() => setLoading(false));
    }
  }, [incident, type]);

  const isSOS = type === 'sos';
  const time = new Date(isSOS ? incident.alerted_at : incident.reported_at);
  const isActive = isSOS ? incident.status === 'active' : incident.status !== 'resolved';
  const isAttended = !isSOS && incident.status === 'attended';

  const handleAction = async (action) => {
    try {
      if (isSOS) {
        if (action === 'resolve') {
          await api.resolveAlert(incident.id);
        }
      } else {
        if (action === 'take') {
          await api.updateReportStatus(incident.id, 'attended');
        } else if (action === 'resolve') {
          await api.updateReportStatus(incident.id, 'resolved');
        }
      }
      onStatusChange();
    } catch (e) {
      console.error(e);
      alert('Action failed');
    }
  };

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content slide-in" onClick={e => e.stopPropagation()}>
        <div className="modal-header">
          <div className="modal-title">
            {isSOS ? 'SOS Alert' : 'Accident Report'} #{incident.id}
          </div>
          <button className="close-btn" onClick={onClose}>✕</button>
        </div>

        <div className="modal-body">
          <div className="detail-section">
            <div className="detail-label">Status & Severity</div>
            <div style={{ display: 'flex', gap: '12px' }}>
              <Badge type={incident.status}>{incident.status}</Badge>
              <Badge type={incident.severity}>{incident.severity}</Badge>
            </div>
          </div>

          <div className="detail-section">
            <div className="detail-label">Location</div>
            <div className="detail-value" style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <MapPin size={18} /> {incident.lat}, {incident.lng}
            </div>
            <div style={{ marginTop: '12px' }}>
              {/* Fake Map placeholder for MVP */}
              <div style={{ height: '150px', background: 'var(--bg-main)', borderRadius: '8px', border: '1px solid var(--border-color)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: 'var(--text-secondary)' }}>
                [Map View Available Here]
              </div>
            </div>
          </div>

          {isSOS && incident.message && (
             <div className="detail-section">
               <div className="detail-label">User Message</div>
               <div className="detail-value">{incident.message}</div>
             </div>
          )}

          {!isSOS && details && (
            <>
              <div className="detail-section">
                <div className="detail-label">Casualties Reported</div>
                <div className="detail-value" style={{ display: 'flex', alignItems: 'center', gap: '8px', color: details.casualties > 0 ? 'var(--accent-red)' : 'inherit' }}>
                  <User size={18} /> {details.casualties} person(s)
                </div>
              </div>

              {details.description && (
                <div className="detail-section">
                  <div className="detail-label">Description</div>
                  <div className="detail-value">{details.description}</div>
                </div>
              )}

              {details.image_path && (
                <div className="detail-section">
                  <div className="detail-label">Evidence Image</div>
                  <img src={`http://localhost:8000/${details.image_path}`} alt="Accident" style={{ width: '100%', borderRadius: '8px', marginTop: '8px' }} />
                </div>
              )}
            </>
          )}

          {!isSOS && loading && <div style={{ color: 'var(--text-secondary)' }}>Loading details...</div>}
        </div>

        {isActive && (
          <div className="modal-actions">
            {!isSOS && incident.status === 'open' && (
              <button className="btn btn-primary" onClick={() => handleAction('take')}>
                Take Report
              </button>
            )}
            <button className="btn btn-success" onClick={() => handleAction('resolve')}>
              <CheckCircle size={18} /> Resolve Incident
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

// --- Main App ---

export default function App() {
  const [alerts, setAlerts] = useState([]);
  const [reports, setReports] = useState([]);
  const [selectedIncident, setSelectedIncident] = useState(null);

  const fetchData = async () => {
    try {
      const a = await api.getAlerts();
      const r = await api.getReports();
      setAlerts(a);
      setReports(r);
      
      // Update selected incident if it's open
      if (selectedIncident) {
        if (selectedIncident.type === 'sos') {
          const updated = a.find(x => x.id === selectedIncident.item.id);
          if (updated) setSelectedIncident({ item: updated, type: 'sos' });
        } else {
          const updated = r.find(x => x.id === selectedIncident.item.id);
          if (updated) setSelectedIncident({ item: updated, type: 'report' });
        }
      }
    } catch (e) {
      console.error("Failed to fetch data", e);
    }
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000); // Poll every 5s
    return () => clearInterval(interval);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const activeAlerts = alerts.filter(a => a.status === 'active');
  const otherAlerts = alerts.filter(a => a.status !== 'active');
  const openReports = reports.filter(r => r.status === 'open' || r.status === 'attended');
  const otherReports = reports.filter(r => r.status === 'resolved');

  return (
    <div className="app-container">
      <nav className="navbar">
        <div className="navbar-brand">
          <ShieldAlert color="var(--accent-red)" />
          RoadSOS Officer Dashboard
        </div>
      </nav>

      <main className="main-content">
        <div className="dashboard-grid">
          
          {/* Column 1: SOS Alerts */}
          <div>
            <div className="section-header">
              <Activity size={18} /> Active SOS Alerts ({activeAlerts.length})
            </div>
            {activeAlerts.length === 0 && <p style={{ color: 'var(--text-secondary)' }}>No active alerts.</p>}
            {activeAlerts.map(a => (
              <Card key={`sos-${a.id}`} item={a} type="sos" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}

            <div className="section-header" style={{ marginTop: '32px' }}>
              Past Alerts
            </div>
            {otherAlerts.slice(0, 5).map(a => (
              <Card key={`sos-${a.id}`} item={a} type="sos" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}
          </div>

          {/* Column 2: Accident Reports */}
          <div>
            <div className="section-header">
              <Car size={18} /> Open Accident Reports ({openReports.length})
            </div>
            {openReports.length === 0 && <p style={{ color: 'var(--text-secondary)' }}>No open reports.</p>}
            {openReports.map(r => (
              <Card key={`rep-${r.id}`} item={r} type="report" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}

            <div className="section-header" style={{ marginTop: '32px' }}>
              Resolved Reports
            </div>
            {otherReports.slice(0, 5).map(r => (
              <Card key={`rep-${r.id}`} item={r} type="report" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}
          </div>

        </div>
      </main>

      {selectedIncident && (
        <IncidentModal 
          incident={selectedIncident.item} 
          type={selectedIncident.type} 
          onClose={() => setSelectedIncident(null)} 
          onStatusChange={() => {
            fetchData();
            setSelectedIncident(null);
          }}
        />
      )}
    </div>
  );
}
