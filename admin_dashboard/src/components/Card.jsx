import React from 'react';
import { formatDistanceToNow } from 'date-fns';
import { Car, MapPin, Clock, Activity } from 'lucide-react';
import { Badge } from './Badge';

export const Card = React.memo(({ item, type, onClick }) => {
  const isSOS = type === 'sos';
  const status = item.status;
  const severity = item.severity;
  const time = new Date(isSOS ? item.alerted_at : item.reported_at);

  return (
    <div className="incident-card fade-in" onClick={() => onClick(item, type)}>
      <div className="incident-header">
        <span className="incident-id">#{item.id} • {isSOS ? 'SOS ALERT' : 'ACCIDENT REPORT'}</span>
        <Badge type={isSOS ? (status === 'active' ? 'active' : 'resolved') : status}>
          {status}
        </Badge>
      </div>
      
      <div className="incident-body">
        {isSOS ? (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: 'var(--accent-red)' }}>
            <Activity size={18} /> Emergency Triggered
          </div>
        ) : (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <Car size={18} /> Accident Reported ({severity})
          </div>
        )}
      </div>

      <div className="incident-footer">
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <MapPin size={14} /> {item.lat.toFixed(4)}, {item.lng.toFixed(4)}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
          <Clock size={14} /> {formatDistanceToNow(time, { addSuffix: true })}
        </div>
      </div>
    </div>
  );
});
