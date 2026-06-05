import React from 'react';
import './LiveIncidentCard.css';
import { PulsingDot } from './PulsingDot';
import { StatusBadge } from './StatusBadge';

// Helper for relative time
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

export function LiveIncidentCard({ item, type, onClick }) {
  const isSos = type === 'sos';
  
  // Defensive data access
  const status = item?.status ?? 'UNKNOWN';
  const officerName = item?.assigned_officer_name ?? item?.officer_name;
  const isDispatched = Boolean(officerName) || 
    (item?.accepted_officer_id !== null && item?.accepted_officer_id !== undefined && item?.accepted_officer_id !== "");
  
  const name = item?.citizen_name 
            ?? item?.reporter_name 
            ?? item?.name 
            ?? item?.user?.name 
            ?? item?.phone_number 
            ?? 'Unknown Reporter';
            
  const lat = item?.latitude ?? item?.lat;
  const lng = item?.longitude ?? item?.lng;
  const hasLocation = lat !== undefined && lat !== null && lng !== undefined && lng !== null;
                      
  const timestamp = item?.created_at ?? item?.timestamp ?? item?.alerted_at;
  const timeStr = timeAgo(timestamp);
  
  const requiresManualDispatch = item?.requires_manual_dispatch;

  return (
    <div 
      className={`incident-card incident-card--${isSos ? 'sos' : 'report'}`}
      onClick={() => onClick(item, type)}
    >
      {/* Row 1: Status */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', zIndex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <PulsingDot color={isSos ? 'red' : 'amber'} size="sm" />
          <StatusBadge status={status} isSos={isSos} />
        </div>
        <div>
          {requiresManualDispatch ? (
            <span style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '10px', fontWeight: 700, color: 'var(--accent-red)', letterSpacing: '0.06em', textTransform: 'uppercase', padding: '2px 6px', border: '1px solid var(--accent-red)', borderRadius: '4px' }}>
              MANUAL DISPATCH
            </span>
          ) : isDispatched ? (
            <StatusBadge status="DISPATCHED" isSos={isSos} />
          ) : (
            <span style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '10px', fontWeight: 600, color: 'var(--text-tertiary)', letterSpacing: '0.06em', textTransform: 'uppercase' }}>
              UNASSIGNED
            </span>
          )}
        </div>
      </div>

      {/* Row 2: Identity */}
      <div style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '15px', fontWeight: 600, color: 'var(--text-primary)', zIndex: 1 }}>
        {name}
      </div>

      {/* Row 3: Location */}
      <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: '11px', color: hasLocation ? 'var(--text-secondary)' : 'var(--text-tertiary)', zIndex: 1 }}>
        {hasLocation 
          ? `Lat ${Number(lat).toFixed(4)}, Lng ${Number(lng).toFixed(4)}`
          : 'Location unavailable'
        }
      </div>

      {/* Row 4: Footer */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 'var(--space-2)', zIndex: 1 }}>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: '11px', color: 'var(--text-tertiary)' }}>
          {timeStr ? `🕐 ${timeStr}` : ''}
        </div>
        <div style={{ fontFamily: 'JetBrains Mono, monospace', fontSize: '11px', color: 'var(--text-tertiary)' }}>
          {item?.id ? `ID: #${item.id}` : 'ID: --'}
        </div>
      </div>
    </div>
  );
}
