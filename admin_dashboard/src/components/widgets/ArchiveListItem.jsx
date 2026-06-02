import React from 'react';
import { StatusBadge } from './StatusBadge';

// Helper for relative time (same as LiveIncidentCard)
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

export function ArchiveListItem({ item, type, onClick }) {
  const isSos = type === 'sos';
  
  // Defensive data access
  const status = item?.status ?? 'UNKNOWN';
  const name = item?.citizen_name 
            ?? item?.reporter_name 
            ?? item?.name 
            ?? item?.user?.name 
            ?? item?.phone_number 
            ?? 'Unknown Reporter';
            
  const timestamp = item?.created_at ?? item?.timestamp;
  const timeStr = timeAgo(timestamp);

  const dotColor = isSos ? 'var(--red-vivid)' : 'var(--amber-vivid)';

  return (
    <div 
      onClick={() => onClick(item, type)}
      style={{
        display: 'flex',
        alignItems: 'flex-start',
        padding: '8px',
        minHeight: '52px',
        borderBottom: '1px solid var(--border-subtle)',
        cursor: 'pointer',
        transition: 'background var(--transition-fast)',
        borderRadius: 'var(--radius-sm)'
      }}
      onMouseEnter={(e) => e.currentTarget.style.background = 'var(--bg-surface-2)'}
      onMouseLeave={(e) => e.currentTarget.style.background = 'transparent'}
    >
      {/* Accent Dot */}
      <div style={{
        width: '6px',
        height: '6px',
        borderRadius: '50%',
        background: dotColor,
        marginTop: '6px',
        marginRight: '12px',
        flexShrink: 0
      }} />

      {/* Center content */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <div style={{
          fontFamily: 'DM Sans, sans-serif',
          fontSize: '13px',
          fontWeight: 500,
          color: 'var(--text-primary)'
        }}>
          {name} {item?.id ? `(#${item.id})` : ''}
        </div>
        <div>
          <StatusBadge status={status} />
        </div>
      </div>

      {/* Right content */}
      <div style={{
        fontFamily: 'JetBrains Mono, monospace',
        fontSize: '10px',
        color: 'var(--text-tertiary)',
        paddingTop: '2px',
        whiteSpace: 'nowrap'
      }}>
        {timeStr}
      </div>
    </div>
  );
}
