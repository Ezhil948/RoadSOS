import React, { useState } from 'react';

/**
 * Finding #10: Admin Dashboard login gate.
 * Prevents unauthenticated access to all citizen PII and incident data.
 * Stores the admin token in sessionStorage (cleared on tab close).
 */
export function AdminLogin({ onLogin }) {
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      const API_BASE = import.meta.env.VITE_API_URL || 'http://localhost:8000/api/v1';
      const res = await fetch(`${API_BASE}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ badge_number: 'admin', password }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => ({}));
        throw new Error(data.detail || 'Authentication failed');
      }

      const data = await res.json();
      sessionStorage.setItem('admin_token', data.access_token);
      onLogin(data.access_token);
    } catch (err) {
      setError(err.message || 'Login failed. Check your credentials.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'var(--bg-void)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: 'DM Sans, sans-serif',
    }}>
      <form onSubmit={handleSubmit} style={{
        background: 'var(--bg-surface-1)',
        border: '1px solid var(--border-default)',
        borderRadius: 'var(--radius-lg)',
        padding: '48px 40px',
        width: '100%',
        maxWidth: '400px',
        boxShadow: 'var(--shadow-lg)',
        display: 'flex',
        flexDirection: 'column',
        gap: '24px',
      }}>
        {/* Header */}
        <div style={{ textAlign: 'center' }}>
          <div style={{
            fontSize: '28px',
            fontFamily: 'Syne, sans-serif',
            fontWeight: 800,
            color: 'var(--red-vivid)',
            letterSpacing: '0.04em',
            marginBottom: '8px',
          }}>
            ROADSOS
          </div>
          <div style={{
            fontSize: '13px',
            color: 'var(--text-secondary)',
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            fontWeight: 600,
          }}>
            Admin Command Center
          </div>
        </div>

        {/* Password field */}
        <div>
          <label style={{
            display: 'block',
            fontSize: '12px',
            fontWeight: 700,
            color: 'var(--text-secondary)',
            letterSpacing: '0.08em',
            textTransform: 'uppercase',
            marginBottom: '8px',
          }}>
            Admin Password
          </label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Enter admin password"
            autoFocus
            required
            style={{
              width: '100%',
              padding: '12px 16px',
              background: 'var(--bg-surface-2)',
              border: '1px solid var(--border-strong)',
              borderRadius: 'var(--radius-sm)',
              color: 'var(--text-primary)',
              fontSize: '15px',
              fontFamily: 'DM Sans, sans-serif',
              outline: 'none',
              boxSizing: 'border-box',
              transition: 'border-color var(--transition-fast)',
            }}
            onFocus={(e) => e.target.style.borderColor = 'var(--blue-vivid)'}
            onBlur={(e) => e.target.style.borderColor = 'var(--border-strong)'}
          />
        </div>

        {/* Error */}
        {error && (
          <div style={{
            background: 'rgba(255, 45, 85, 0.08)',
            border: '1px solid rgba(255, 45, 85, 0.2)',
            borderRadius: 'var(--radius-xs)',
            padding: '10px 14px',
            color: 'var(--red-vivid)',
            fontSize: '13px',
            fontWeight: 500,
          }}>
            {error}
          </div>
        )}

        {/* Submit */}
        <button
          type="submit"
          disabled={loading || !password}
          style={{
            padding: '14px',
            background: loading ? 'var(--bg-surface-2)' : 'var(--red-vivid)',
            color: loading ? 'var(--text-tertiary)' : '#fff',
            border: 'none',
            borderRadius: 'var(--radius-sm)',
            fontSize: '15px',
            fontWeight: 700,
            fontFamily: 'Syne, sans-serif',
            letterSpacing: '0.06em',
            cursor: loading ? 'not-allowed' : 'pointer',
            transition: 'all var(--transition-fast)',
            textTransform: 'uppercase',
          }}
        >
          {loading ? 'Authenticating...' : 'Enter Dashboard'}
        </button>

        <div style={{
          fontSize: '11px',
          color: 'var(--text-tertiary)',
          textAlign: 'center',
          lineHeight: '1.6',
        }}>
          Authorized personnel only. All access is logged.
        </div>
      </form>
    </div>
  );
}
