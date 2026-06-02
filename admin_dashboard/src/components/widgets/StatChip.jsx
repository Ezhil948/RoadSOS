import React from 'react';

export function StatChip({ value, label, accent }) {
  let textColor;
  switch (accent) {
    case 'red': textColor = 'var(--red-vivid)'; break;
    case 'amber': textColor = 'var(--amber-vivid)'; break;
    case 'green': textColor = 'var(--green-vivid)'; break;
    case 'default':
    default:
      textColor = 'var(--text-primary)';
      break;
  }

  return (
    <div style={{
      background: 'var(--bg-surface-2)',
      border: '1px solid var(--border-default)',
      borderRadius: 'var(--radius-pill)',
      padding: '4px 14px',
      display: 'inline-flex',
      alignItems: 'center',
      gap: '8px'
    }}>
      <span style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '18px', fontWeight: 500, color: textColor }}>
        {value}
      </span>
      <span style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '11px', fontWeight: 500, color: 'var(--text-secondary)' }}>
        {label}
      </span>
    </div>
  );
}
