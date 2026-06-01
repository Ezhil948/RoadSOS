import React from 'react';

export const Badge = ({ type, children }) => (
  <span className={`badge ${type}`}>{children}</span>
);
