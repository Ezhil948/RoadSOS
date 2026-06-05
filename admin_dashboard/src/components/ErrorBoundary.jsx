import React from 'react';

/**
 * Finding #25: Error Boundary to prevent the entire dashboard from crashing
 * when a single component throws (e.g., null status from bad API data).
 * Without this, one bad data point crashes the entire command center.
 */
export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    console.error('Dashboard error boundary caught:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{
          padding: '40px',
          color: 'var(--text-primary)',
          textAlign: 'center',
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: '16px',
        }}>
          <div style={{
            width: '56px',
            height: '56px',
            borderRadius: '50%',
            background: 'rgba(255, 159, 10, 0.1)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '24px',
          }}>
            ⚠️
          </div>
          <h2 style={{
            fontFamily: 'Syne, sans-serif',
            fontSize: '18px',
            fontWeight: 700,
            margin: 0,
          }}>
            Component Error
          </h2>
          <p style={{
            color: 'var(--text-secondary)',
            fontFamily: 'DM Sans, sans-serif',
            fontSize: '14px',
            maxWidth: '400px',
            margin: 0,
          }}>
            A display error occurred. Live data feed is still active.
            Click retry to reload this section.
          </p>
          <button
            onClick={() => this.setState({ hasError: false, error: null })}
            style={{
              marginTop: '8px',
              padding: '10px 28px',
              background: 'var(--blue-vivid)',
              color: '#fff',
              border: 'none',
              borderRadius: 'var(--radius-sm)',
              fontFamily: 'DM Sans, sans-serif',
              fontSize: '14px',
              fontWeight: 600,
              cursor: 'pointer',
              transition: 'all var(--transition-fast)',
            }}
            onMouseEnter={(e) => e.currentTarget.style.filter = 'brightness(1.15)'}
            onMouseLeave={(e) => e.currentTarget.style.filter = 'brightness(1)'}
          >
            Retry
          </button>
          {this.state.error && (
            <details style={{
              marginTop: '12px',
              color: 'var(--text-tertiary)',
              fontFamily: 'JetBrains Mono, monospace',
              fontSize: '11px',
              maxWidth: '500px',
              textAlign: 'left',
            }}>
              <summary style={{ cursor: 'pointer', marginBottom: '8px' }}>Technical Details</summary>
              <pre style={{
                background: 'var(--bg-surface-2)',
                padding: '12px',
                borderRadius: 'var(--radius-xs)',
                overflow: 'auto',
                whiteSpace: 'pre-wrap',
              }}>
                {this.state.error.toString()}
              </pre>
            </details>
          )}
        </div>
      );
    }
    return this.props.children;
  }
}
