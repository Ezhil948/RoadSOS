import React from 'react';

export function SectionHeader({ icon, label, count, accent }) {
  const accentColor = accent === 'red' ? 'var(--red-vivid)' : 'var(--amber-vivid)';
  const clonedIcon = React.cloneElement(icon, { color: accentColor, size: 16 });

  return (
    <div style={{ marginBottom: 'var(--space-4)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
        {clonedIcon}
        <span style={{
          fontFamily: 'Syne, sans-serif',
          fontSize: '11px',
          fontWeight: 700,
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          color: 'var(--text-secondary)'
        }}>
          {label}
        </span>
        <span style={{
          background: count > 0 ? (accent === 'red' ? 'var(--red-fill)' : 'var(--amber-fill)') : 'var(--bg-surface-2)',
          color: count > 0 ? (accent === 'red' ? 'var(--red-vivid)' : 'var(--amber-vivid)') : 'var(--text-tertiary)',
          fontFamily: 'DM Sans, sans-serif',
          fontSize: '11px',
          fontWeight: 600,
          padding: '2px 8px',
          borderRadius: 'var(--radius-pill)'
        }}>
          {count}
        </span>
      </div>
      <div style={{ borderBottom: '1px solid var(--border-subtle)', marginTop: 'var(--space-3)' }} />
    </div>
  );
}
