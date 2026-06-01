export class IncidentEntity {
  constructor({ id, type, status, latitude, longitude, createdAt, data }) {
    this.id = id;
    this.type = type; // 'sos' or 'report'
    this.status = status; 
    this.latitude = latitude;
    this.longitude = longitude;
    this.createdAt = createdAt;
    this.data = data; // Original raw data
  }

  get isActive() {
    return this.type === 'sos' 
      ? this.status === 'active' 
      : (this.status === 'open' || this.status === 'attended');
  }
}
