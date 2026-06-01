import { IncidentEntity } from '../entities/IncidentEntity';

export class FetchDashboardDataUseCase {
  constructor(repository) {
    this.repository = repository;
  }

  async execute() {
    // Fetch raw data concurrently
    const [rawAlerts, rawReports] = await Promise.all([
      this.repository.fetchAlerts(),
      this.repository.fetchReports()
    ]);

    // Domain Transformation Rule: Convert raw JSON into Domain Entities
    const sosEntities = rawAlerts.map(a => new IncidentEntity({
      id: a.id,
      type: 'sos',
      status: a.status,
      latitude: a.latitude,
      longitude: a.longitude,
      createdAt: a.created_at,
      data: a
    }));

    const reportEntities = rawReports.map(r => new IncidentEntity({
      id: r.id,
      type: 'report',
      status: r.status,
      latitude: r.latitude,
      longitude: r.longitude,
      createdAt: r.created_at,
      data: r
    }));

    // Domain Sorting Rule: Active incidents first, then sort by ID/Time
    const activeSos = sosEntities.filter(e => e.isActive);
    const pastSos = sosEntities.filter(e => !e.isActive);
    
    const activeReports = reportEntities.filter(e => e.isActive);
    const pastReports = reportEntities.filter(e => !e.isActive);

    return {
      activeSos,
      pastSos,
      activeReports,
      pastReports
    };
  }
}
