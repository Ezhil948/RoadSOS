import React from 'react';
import { PulsingDot } from '../widgets/PulsingDot';

const SectionLabel = ({ text }) => (
  <div style={{
    fontFamily: 'Syne, sans-serif',
    fontSize: '10px',
    fontWeight: 700,
    letterSpacing: '0.1em',
    color: 'var(--text-tertiary)',
    textTransform: 'uppercase',
    paddingBottom: '12px'
  }}>
    {text}
  </div>
);

const Divider = () => (
  <div style={{
    height: '1px',
    background: 'var(--border-subtle)',
    margin: '20px 0'
  }} />
);

const GlassCard = ({ children, style = {} }) => (
  <div style={{
    background: 'var(--bg-glass)',
    border: 'var(--glass-border)',
    borderRadius: 'var(--radius-md)',
    padding: 'var(--space-4)',
    ...style
  }}>
    {children}
  </div>
);

export function LeftPanel() {
  return (
    <div style={{
      width: 'var(--left-panel-width)',
      flexShrink: 0,
      background: 'var(--bg-surface-1)',
      borderRight: '1px solid var(--border-subtle)',
      padding: 'var(--space-6) var(--space-4)',
      overflowY: 'auto'
    }}>
      
      <SectionLabel text="SYSTEM STATUS" />
      <GlassCard>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '4px' }}>
          <PulsingDot color="green" size="sm" />
          <span style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '13px', color: 'var(--text-secondary)' }}>
            Backend Connected
          </span>
        </div>
        <div className="mono" style={{ fontSize: '11px', color: 'var(--text-tertiary)', paddingLeft: '15px' }}>
          Polling every 10s
        </div>
      </GlassCard>

      <Divider />

      <SectionLabel text="UNITS ON DUTY" />
      <GlassCard style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 'var(--space-5) var(--space-4)' }}>
        {/* TODO: Connect to /officers/active endpoint */}
        <div style={{ fontFamily: 'Syne, sans-serif', fontSize: '32px', fontWeight: 300, color: 'var(--text-primary)', lineHeight: 1 }}>
          —
        </div>
        <div style={{ fontFamily: 'DM Sans, sans-serif', fontSize: '11px', color: 'var(--text-secondary)', marginTop: '8px' }}>
          Officers Active
        </div>
      </GlassCard>

      <Divider />

      <SectionLabel text="RESPONSE ZONES" />
      <GlassCard>
        {/* TODO: Connect to zone API */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontFamily: 'DM Sans, sans-serif', fontSize: '12px', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '10px' }}>🟢</span> Zone Alpha — Clear
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontFamily: 'DM Sans, sans-serif', fontSize: '12px', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '10px' }}>🟡</span> Zone Bravo — Moderate
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', fontFamily: 'DM Sans, sans-serif', fontSize: '12px', color: 'var(--text-secondary)' }}>
            <span style={{ fontSize: '10px' }}>🔴</span> Zone Charlie — High
          </div>
        </div>
      </GlassCard>

    </div>
  );
}
