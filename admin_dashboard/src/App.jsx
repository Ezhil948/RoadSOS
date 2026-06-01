import React, { useState, useEffect } from 'react';
import { ShieldAlert, Car, Activity } from 'lucide-react';
import './index.css';
import { Card } from './components/Card';
import { IncidentModal } from './components/IncidentModal';
import { useDashboardData } from './presentation/state/useDashboardData';

export default function App() {
  const { activeSos, pastSos, activeReports, pastReports, isLoading, refreshData } = useDashboardData(10000);
  const [selectedIncident, setSelectedIncident] = useState(null);

  useEffect(() => {
    if (selectedIncident) {
      if (selectedIncident.type === 'sos') {
        const updated = [...activeSos, ...pastSos].find(x => x.id === selectedIncident.item.id);
        if (updated) setSelectedIncident({ item: updated.data, type: 'sos' });
      } else {
        const updated = [...activeReports, ...pastReports].find(x => x.id === selectedIncident.item.id);
        if (updated) setSelectedIncident({ item: updated.data, type: 'report' });
      }
    }
  }, [activeSos, pastSos, activeReports, pastReports]);

  return (
    <div className="app-container">
      <nav className="navbar">
        <div className="navbar-brand">
          <ShieldAlert color="var(--accent-red)" />
          RoadSOS Officer Dashboard
        </div>
      </nav>

      <main className="main-content">
        <div className="dashboard-grid">
          
          {/* Column 1: SOS Alerts */}
          <div>
            <div className="section-header">
              <Activity size={18} /> Active SOS Alerts ({activeSos.length})
            </div>
            {activeSos.length === 0 && <p style={{ color: 'var(--text-secondary)' }}>No active alerts.</p>}
            {activeSos.map(a => (
              <Card key={`sos-${a.id}`} item={a.data} type="sos" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}

            <div className="section-header" style={{ marginTop: '32px' }}>
              Past Alerts
            </div>
            {pastSos.slice(0, 5).map(a => (
              <Card key={`sos-${a.id}`} item={a.data} type="sos" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}
          </div>

          {/* Column 2: Accident Reports */}
          <div>
            <div className="section-header">
              <Car size={18} /> Open Accident Reports ({activeReports.length})
            </div>
            {activeReports.length === 0 && <p style={{ color: 'var(--text-secondary)' }}>No open reports.</p>}
            {activeReports.map(r => (
              <Card key={`rep-${r.id}`} item={r.data} type="report" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}

            <div className="section-header" style={{ marginTop: '32px' }}>
              Resolved Reports
            </div>
            {pastReports.slice(0, 5).map(r => (
              <Card key={`rep-${r.id}`} item={r.data} type="report" onClick={(item, type) => setSelectedIncident({ item, type })} />
            ))}
          </div>

        </div>
      </main>

      {selectedIncident && (
        <IncidentModal 
          incident={selectedIncident.item} 
          type={selectedIncident.type} 
          onClose={() => setSelectedIncident(null)} 
          onStatusChange={() => {
            refreshData();
            setSelectedIncident(null);
          }}
        />
      )}
    </div>
  );
}
