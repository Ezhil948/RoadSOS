import React, { useState, useEffect } from 'react';
import { useDashboardData } from './presentation/state/useDashboardData';
import { TopCommandBar } from './components/layout/TopCommandBar';
import { LeftPanel } from './components/layout/LeftPanel';
import { MainCanvas } from './components/layout/MainCanvas';
import { AlertFeed } from './components/layout/AlertFeed';
import { IncidentModal } from './components/overlays/IncidentModal';
import './styles/tokens.css';
import './index.css';

export default function App() {
  const { activeSos, pastSos, activeReports, pastReports, isLoading, error, refreshData } = useDashboardData(10000);
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

  const handleCardClick = (item, type) => setSelectedIncident({ item, type });
  const handleClose = () => setSelectedIncident(null);
  const handleStatusChange = () => { refreshData(); setSelectedIncident(null); };

  return (
    <div className="app-shell">
      <TopCommandBar
        isLoading={isLoading}
        error={error}
        refreshData={refreshData}
        totalActive={activeSos.length + activeReports.length}
        totalSos={activeSos.length}
        totalReports={activeReports.length}
      />
      <div className="app-body">
        <LeftPanel pastSos={pastSos} pastReports={pastReports} />
        <MainCanvas
          activeSos={activeSos}
          activeReports={activeReports}
          onCardClick={handleCardClick}
        />
        <AlertFeed
          pastSos={pastSos}
          pastReports={pastReports}
          onItemClick={handleCardClick}
        />
      </div>
      {selectedIncident && (
        <IncidentModal
          incident={selectedIncident.item}
          type={selectedIncident.type}
          onClose={handleClose}
          onStatusChange={handleStatusChange}
        />
      )}
    </div>
  );
}
