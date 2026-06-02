import React, { useState, useEffect } from 'react';
import { MapPin, CheckCircle, User, X, Clock } from 'lucide-react';
import { StatusBadge } from '../widgets/StatusBadge';
import { api } from '../../api';

// Helper for relative time (same as LiveIncidentCard)
const API_BASE_URL = import.meta.env.VITE_API_URL ? import.meta.env.VITE_API_URL.replace('/api/v1', '') : 'http://localhost:8000';

function timeAgo(dateInput) {
  if (!dateInput) return '';
  const date = new Date(dateInput);
  if (isNaN(date)) return '';
  const seconds = Math.floor((new Date() - date) / 1000);
  if (seconds < 60) return `${Math.max(0, seconds)} secs ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} min${minutes !== 1 ? 's' : ''} ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hr${hours !== 1 ? 's' : ''} ago`;
  const days = Math.floor(hours / 24);
  return `${days} day${days !== 1 ? 's' : ''} ago`;
}

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
  }, [incident.id, type]);

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

  const name = incident?.citizen_name ?? incident?.reporter_name ?? incident?.name ?? incident?.user?.name ?? incident?.phone_number ?? 'Unknown Reporter';
  const timestamp = incident?.created_at ?? incident?.timestamp;

  return (
    <div style={{
      position: 'fixed',
      inset: 0,
      background: 'rgba(7, 10, 16, 0.85)',
      backdropFilter: 'blur(8px)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      zIndex: 1000
    }} onClick={onClose}>
      
      <div style={{
        background: 'var(--bg-glass)',
        backdropFilter: 'var(--glass-blur)',
        border: '1px solid var(--border-strong)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-lg)',
        width: '100%',
        maxWidth: '520px',
        minWidth: '360px',
        borderTop: `3px solid ${isSOS ? 'var(--red-vivid)' : 'var(--amber-vivid)'}`,
        display: 'flex',
        flexDirection: 'column',
        maxHeight: '90vh'
      }} onClick={e => e.stopPropagation()}>
        
        {/* Header */}
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          padding: 'var(--space-5) var(--space-6)',
          borderBottom: '1px solid var(--border-default)'
        }}>
          <div>
            <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '18px', fontWeight: 700, color: 'var(--text-primary)' }}>
              {isSOS ? 'SOS ALERT' : 'ACCIDENT REPORT'}
            </div>
            <div className="mono" style={{ fontSize: '11px', color: 'var(--text-tertiary)', marginTop: '4px' }}>
              ID: #{incident.id}
            </div>
          </div>
          
          <button onClick={onClose} style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '6px 10px',
            borderRadius: 'var(--radius-sm)',
            border: '1px solid var(--border-default)',
            color: 'var(--text-primary)',
            transition: 'all var(--transition-fast)'
          }}
          onMouseEnter={(e) => {
            e.currentTarget.style.borderColor = 'var(--border-strong)';
            e.currentTarget.style.background = 'var(--bg-surface-2)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.borderColor = 'var(--border-default)';
            e.currentTarget.style.background = 'transparent';
          }}>
            <X size={16} />
          </button>
        </div>

        {/* Body */}
        <div style={{ padding: 'var(--space-6)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 'var(--space-5)' }}>
          
          <div style={{ display: 'flex', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Status</div>
              <div style={{ display: 'flex', gap: '8px' }}>
                <StatusBadge status={incident.status} />
                {incident.severity && <StatusBadge status={incident.severity} />}
              </div>
            </div>
          </div>

          <div>
            <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Reporter</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontFamily: 'DM Sans, sans-serif', fontSize: '15px' }}>
              <User size={16} color="var(--text-secondary)" /> {name}
            </div>
          </div>

          <div>
            <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Location</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontFamily: 'DM Sans, sans-serif', fontSize: '15px' }}>
              <MapPin size={16} color="var(--text-secondary)" /> {incident.lat ?? incident.latitude}, {incident.lng ?? incident.longitude}
            </div>
          </div>

          <div>
            <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Time</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--text-primary)', fontFamily: 'DM Sans, sans-serif', fontSize: '15px' }}>
              <Clock size={16} color="var(--text-secondary)" /> {timeAgo(timestamp)}
            </div>
          </div>

          {isSOS && incident.message && (
             <div>
               <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>User Message</div>
               <div style={{ background: 'var(--bg-surface-2)', padding: 'var(--space-4)', borderRadius: 'var(--radius-sm)', fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-primary)' }}>
                 {incident.message}
               </div>
             </div>
          )}

          {isSOS && incident.status === 'resolved' && (
             <>
               <div>
                 <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px', marginTop: '16px' }}>Resolution Details</div>
                 <div style={{ background: 'var(--bg-surface-2)', padding: 'var(--space-4)', borderRadius: 'var(--radius-sm)', fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-primary)' }}>
                   <div style={{ marginBottom: '4px' }}><strong style={{ color: 'var(--text-secondary)' }}>Category:</strong> {incident.category || 'N/A'}</div>
                   <div><strong style={{ color: 'var(--text-secondary)' }}>Notes:</strong> {incident.closure_notes || 'None provided'}</div>
                 </div>
               </div>
               
               {incident.closure_photo_urls && incident.closure_photo_urls.length > 0 && (
                 <div>
                   <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px', marginTop: '16px' }}>Resolution Photos</div>
                   <div style={{ display: 'flex', gap: '8px', overflowX: 'auto' }}>
                     {incident.closure_photo_urls.map((url, i) => (
                       <img key={i} src={`${API_BASE_URL}/${url}`} alt="Resolution" style={{ height: '120px', borderRadius: 'var(--radius-sm)' }} />
                     ))}
                   </div>
                 </div>
               )}
             </>
          )}

          {!isSOS && details && (
            <>
              <div>
                <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Casualties</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: details.casualties > 0 ? 'var(--red-vivid)' : 'var(--text-primary)', fontFamily: 'DM Sans, sans-serif', fontSize: '15px' }}>
                  <User size={16} /> {details.casualties} person(s)
                </div>
              </div>

              {details.description && (
                <div>
                  <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Description</div>
                  <div style={{ background: 'var(--bg-surface-2)', padding: 'var(--space-4)', borderRadius: 'var(--radius-sm)', fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-primary)' }}>
                    {details.description}
                  </div>
                </div>
              )}

              {details.image_path && (
                <div>
                  <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '13px', fontWeight: 700, letterSpacing: '0.08em', color: 'var(--text-secondary)', textTransform: 'uppercase', marginBottom: '8px' }}>Evidence Image</div>
                  <img src={`${API_BASE_URL}/${details.image_path}`} alt="Accident" style={{ width: '100%', borderRadius: 'var(--radius-sm)', marginTop: '8px' }} />
                </div>
              )}
            </>
          )}

          {!isSOS && loading && <div style={{ color: 'var(--text-tertiary)', fontSize: '13px' }}>Loading details...</div>}
        </div>

        {/* Footer Actions */}
        {isActive && (
          <div style={{
            padding: 'var(--space-5) var(--space-6)',
            borderTop: '1px solid var(--border-default)',
            background: 'var(--bg-surface-1)',
            display: 'flex',
            gap: 'var(--space-4)',
            borderBottomLeftRadius: 'var(--radius-lg)',
            borderBottomRightRadius: 'var(--radius-lg)'
          }}>
            {!isSOS && incident.status === 'open' && (
              <button onClick={() => handleAction('take')} style={{
                flex: 1,
                padding: '10px 20px',
                borderRadius: 'var(--radius-sm)',
                background: 'var(--bg-surface-2)',
                color: 'var(--text-primary)',
                fontFamily: 'DM Sans, sans-serif',
                fontSize: '14px',
                fontWeight: 600,
                border: '1px solid var(--border-strong)',
                transition: 'all var(--transition-fast)',
                cursor: 'pointer'
              }}
              onMouseEnter={(e) => e.currentTarget.style.background = 'var(--bg-glass-hover)'}
              onMouseLeave={(e) => e.currentTarget.style.background = 'var(--bg-surface-2)'}>
                Take Report
              </button>
            )}
            <button onClick={() => handleAction('resolve')} style={{
              flex: 1,
              padding: '10px 20px',
              borderRadius: 'var(--radius-sm)',
              background: 'var(--green-vivid)',
              color: '#000',
              fontFamily: 'DM Sans, sans-serif',
              fontSize: '14px',
              fontWeight: 600,
              border: 'none',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '8px',
              transition: 'all var(--transition-fast)',
              cursor: 'pointer'
            }}
            onMouseEnter={(e) => e.currentTarget.style.filter = 'brightness(1.1)'}
            onMouseLeave={(e) => e.currentTarget.style.filter = 'brightness(1)'}>
              <CheckCircle size={18} /> Mark Resolved
            </button>
          </div>
        )}
      </div>
    </div>
  );
};
