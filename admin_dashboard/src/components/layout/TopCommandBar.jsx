import React, { useState, useEffect } from 'react';
import { ShieldAlert, RotateCw, LogOut } from 'lucide-react';
import { StatChip } from '../widgets/StatChip';
import { PulsingDot } from '../widgets/PulsingDot';

export function TopCommandBar({ isLoading, error, refreshData, totalActive, totalSos, totalReports, onLogout }) {
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    const interval = setInterval(() => {
      setNow(new Date());
    }, 1000);
    return () => clearInterval(interval);
  }, []);

  const timeString = now.toLocaleTimeString('en-US', { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
  const dateString = now.toLocaleDateString('en-US', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' }).toUpperCase();

  return (
    <>
      <div style={{
        position: 'sticky',
        top: 0,
        zIndex: 100,
        height: 'var(--topbar-height)',
        width: '100%',
        background: 'var(--bg-glass)',
        backdropFilter: 'var(--glass-blur)',
        borderBottom: '1px solid var(--border-default)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 var(--space-6)',
        overflow: 'hidden'
      }}>
        
        {/* Left: Brand */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
          <ShieldAlert color="var(--red-vivid)" size={20} />
          <span style={{ fontFamily: 'Syne, sans-serif', fontSize: '15px', fontWeight: 700, letterSpacing: '0.12em', color: 'var(--text-primary)' }}>
            ROADSOS HQ
          </span>
          <div style={{ width: '1px', height: '24px', background: 'var(--border-default)', marginLeft: 'var(--space-3)' }} />
        </div>

        {/* Center: Clock */}
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center' }}>
          <span className="mono" style={{ fontSize: '20px', fontWeight: 500, color: 'var(--text-primary)', lineHeight: 1.1 }}>
            {timeString}
          </span>
          <span style={{ fontSize: '11px', color: 'var(--text-tertiary)', marginTop: '2px' }}>
            {dateString}
          </span>
        </div>

        {/* Right: Controls */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-4)' }}>
          <StatChip value={totalActive} label="Total Active" accent="red" />
          <StatChip value={totalSos} label="SOS Alerts" accent="amber" />
          <StatChip value={totalReports} label="Reports" accent="default" />
          
          <div style={{ width: '1px', height: '24px', background: 'var(--border-default)', margin: '0 var(--space-2)' }} />

          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '75px' }}>
            {isLoading ? (
              <>
                <div style={{ 
                  width: '16px', height: '16px', borderRadius: '50%', 
                  border: '2px solid var(--text-tertiary)', borderTopColor: 'var(--green-vivid)',
                  animation: 'spin 1s linear infinite'
                }} />
                <span style={{ fontSize: '11px', fontWeight: 600, color: 'var(--text-tertiary)' }}>SYNCING</span>
              </>
            ) : (
              <>
                <PulsingDot color="green" size="sm" />
                <span style={{ fontSize: '11px', fontWeight: 600, color: 'var(--green-vivid)' }}>LIVE</span>
              </>
            )}
          </div>

          <button onClick={refreshData} title="Refresh Data" style={{
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
            e.currentTarget.style.background = 'var(--bg-surface-1)';
          }}
          onMouseLeave={(e) => {
            e.currentTarget.style.borderColor = 'var(--border-default)';
            e.currentTarget.style.background = 'transparent';
          }}>
            <RotateCw size={16} />
          </button>

          {onLogout && (
            <button onClick={onLogout} title="Logout" style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              padding: '6px 10px',
              borderRadius: 'var(--radius-sm)',
              border: '1px solid var(--border-default)',
              color: 'var(--red-vivid)',
              transition: 'all var(--transition-fast)',
              cursor: 'pointer',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.borderColor = 'var(--red-vivid)';
              e.currentTarget.style.background = 'rgba(255,45,85,0.08)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.borderColor = 'var(--border-default)';
              e.currentTarget.style.background = 'transparent';
            }}>
              <LogOut size={16} />
            </button>
          )}
        </div>
      </div>

      {error && (
        <div style={{
          position: 'absolute',
          top: 'var(--topbar-height)',
          left: 0,
          right: 0,
          height: '32px',
          background: 'rgba(255,45,85,0.12)',
          borderBottom: '1px solid var(--red-border)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          zIndex: 99,
          fontSize: '12px',
          color: 'var(--red-vivid)'
        }}>
          ⚠ Connection error: {error}
        </div>
      )}
      <style>{`
        @keyframes spin { 100% { transform: rotate(360deg); } }
      `}</style>
    </>
  );
}
