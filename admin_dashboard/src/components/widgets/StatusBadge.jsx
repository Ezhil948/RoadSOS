import React from 'react';

export function StatusBadge({ status }) {
  const upperStatus = (status || '').toUpperCase();
  let fill, textColor, label, borderColor;

  switch (upperStatus) {
    case 'ACTIVE':
    case 'OPEN':
    case 'PENDING':
      label = 'ACTIVE';
      fill = 'var(--red-fill)';
      textColor = 'var(--red-vivid)';
      borderColor = 'var(--red-border)';
      break;
    case 'DISPATCHED':
    case 'ASSIGNED':
      label = 'DISPATCHED';
      fill = 'var(--blue-fill)';
      textColor = 'var(--blue-vivid)';
      borderColor = 'var(--blue-border)';
      break;
    case 'RESOLVED':
    case 'CLOSED':
    case 'PAST':
      label = 'RESOLVED';
      fill = 'var(--green-fill)';
      textColor = 'var(--green-vivid)';
      borderColor = 'var(--green-border)';
      break;
    case 'INVESTIGATING':
    case 'IN_PROGRESS':
      label = 'IN PROGRESS';
      fill = 'var(--amber-fill)';
      textColor = 'var(--amber-vivid)';
      borderColor = 'var(--amber-border)';
      break;
    default:
      label = status;
      fill = 'var(--bg-surface-2)';
      textColor = 'var(--text-secondary)';
      borderColor = 'var(--border-default)';
  }

  return (
    <span style={{
      display: 'inline-flex',
      alignItems: 'center',
      padding: '2px 8px',
      borderRadius: 'var(--radius-pill)',
      fontFamily: "'DM Sans', sans-serif",
      fontSize: '10px',
      fontWeight: 600,
      letterSpacing: '0.06em',
      textTransform: 'uppercase',
      background: fill,
      color: textColor,
      border: `1px solid ${borderColor}`
    }}>
      {label}
    </span>
  );
}
