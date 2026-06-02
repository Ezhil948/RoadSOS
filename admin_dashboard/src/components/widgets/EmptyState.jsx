import React from 'react';

export function EmptyState({ icon, message }) {
  const clonedIcon = React.cloneElement(icon, { size: 32, color: 'var(--text-tertiary)' });

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      padding: 'var(--space-10) var(--space-6)',
      position: 'relative'
    }}>
      {/* Background glow */}
      <div style={{
        position: 'absolute',
        width: '60px',
        height: '60px',
        background: 'var(--border-default)',
        filter: 'blur(24px)',
        borderRadius: '50%',
        zIndex: 0
      }} />
      
      <div style={{ zIndex: 1, marginBottom: 'var(--space-4)' }}>
        {clonedIcon}
      </div>
      
      <div style={{ zIndex: 1, fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-tertiary)', textAlign: 'center' }}>
        {message}
      </div>
    </div>
  );
}
