import React from 'react';

export function PulsingDot({ color, size = 'sm' }) {
  return <span className={`pulsing-dot pulsing-dot--${color} pulsing-dot--${size}`} />;
}
