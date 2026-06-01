import React, { useState, useEffect } from 'react';
import { MapPin, CheckCircle, User } from 'lucide-react';
import { Badge } from './Badge';
import { api } from '../api';

export const IncidentModal = ({ incident, type, onClose, onStatusChange }) => {
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
  const isActive = isSOS ? incident.status === 'active' : incident.status !== 'resolved';

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
