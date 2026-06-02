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
      
      <div style={{ zIndex: 1, marginBottom: 'var(--space-4)' }}>
        {clonedIcon}
      </div>
      
      <div style={{ zIndex: 1, fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-tertiary)', textAlign: 'center' }}>
        {message}
      </div>
    </div>
  );
}
