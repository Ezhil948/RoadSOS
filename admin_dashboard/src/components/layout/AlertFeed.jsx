import React from 'react';
import { Clock } from 'lucide-react';
import { ArchiveListItem } from '../widgets/ArchiveListItem';

export function AlertFeed({ pastSos, pastReports, onItemClick }) {
  
  return (
    <div style={{
      width: 'var(--right-feed-width)',
      flexShrink: 0,
      background: 'var(--bg-surface-1)',
      borderLeft: '1px solid var(--border-subtle)',
      overflowY: 'auto',
      padding: 'var(--space-4)',
      position: 'relative'
    }}>
      
      {/* Sticky Header */}
      <div style={{
        position: 'sticky',
        top: 0,
        background: 'var(--bg-surface-1)',
        zIndex: 10,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        paddingBottom: 'var(--space-4)',
        borderBottom: '1px solid var(--border-subtle)',
        marginBottom: 'var(--space-4)'
      }}>
        <span style={{
          fontFamily: 'Syne, sans-serif',
          fontSize: '10px',
          textTransform: 'uppercase',
          letterSpacing: '0.1em',
          color: 'var(--text-tertiary)',
          fontWeight: 700
        }}>
          INCIDENT ARCHIVE
        </span>
        <Clock size={14} color="var(--text-tertiary)" />
      </div>

      {/* SOS History */}
      <div style={{ 
        fontFamily: 'DM Sans, sans-serif', 
        fontSize: '11px', 
        fontWeight: 600, 
        color: 'var(--text-secondary)',
        marginBottom: 'var(--space-3)' 
      }}>
        SOS History
      </div>
      
      {pastSos.length === 0 ? (
        <div style={{ fontSize: '11px', fontStyle: 'italic', color: 'var(--text-tertiary)', marginBottom: 'var(--space-4)' }}>
          No past SOS alerts.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
          {pastSos.slice(0, 10).map(a => (
            <ArchiveListItem key={a.id} item={a.data} type="sos" onClick={onItemClick} />
          ))}
        </div>
      )}

      {/* Divider */}
      <div className="feed-divider">REPORTS</div>

      {/* Report History */}
      <div style={{ 
        fontFamily: 'DM Sans, sans-serif', 
        fontSize: '11px', 
        fontWeight: 600, 
        color: 'var(--text-secondary)',
        marginBottom: 'var(--space-3)' 
      }}>
        Report History
      </div>

      {pastReports.length === 0 ? (
        <div style={{ fontSize: '11px', fontStyle: 'italic', color: 'var(--text-tertiary)' }}>
          No past reports.
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
          {pastReports.slice(0, 10).map(r => (
            <ArchiveListItem key={r.id} item={r.data} type="report" onClick={onItemClick} />
          ))}
        </div>
      )}
      
    </div>
  );
}
