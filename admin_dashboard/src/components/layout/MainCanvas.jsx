import React from 'react';
import { Activity, Car, ShieldCheck, CheckCircle } from 'lucide-react';
import { SectionHeader } from '../widgets/SectionHeader';
import { LiveIncidentCard } from '../widgets/LiveIncidentCard';
import { EmptyState } from '../widgets/EmptyState';

export function MainCanvas({ activeSos, activeReports, onCardClick }) {
  
  return (
    <div className="main-canvas">
      
      {/* SECTION A: Active SOS Alerts */}
      <section>
        <SectionHeader 
          icon={<Activity />} 
          label="ACTIVE SOS ALERTS" 
          count={activeSos.length} 
          accent="red" 
        />
        
        {activeSos.length === 0 ? (
          <EmptyState 
            icon={<ShieldCheck />} 
            message="All clear — no active SOS alerts." 
          />
        ) : (
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
            gap: 'var(--space-4)'
          }}>
            {activeSos.map(a => (
              <LiveIncidentCard 
                key={a.id} 
                item={a.data} 
                type="sos" 
                onClick={onCardClick} 
              />
            ))}
          </div>
        )}
      </section>

      {/* SECTION B: Open Accident Reports */}
      <section>
        <SectionHeader 
          icon={<Car />} 
          label="OPEN ACCIDENT REPORTS" 
          count={activeReports.length} 
          accent="amber" 
        />
        
        {activeReports.length === 0 ? (
          <EmptyState 
            icon={<CheckCircle />} 
            message="All clear — no open reports." 
          />
        ) : (
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))',
            gap: 'var(--space-4)'
          }}>
            {activeReports.map(r => (
              <LiveIncidentCard 
                key={r.id} 
                item={r.data} 
                type="report" 
                onClick={onCardClick} 
              />
            ))}
          </div>
        )}
      </section>

    </div>
  );
}
