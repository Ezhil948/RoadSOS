/**
 * IDashboardRepository Interface
 * 
 * Enforced via JSDoc since JavaScript doesn't have native interfaces.
 * 
 * @interface
 */
export class IDashboardRepository {
  /**
   * @returns {Promise<Array<Object>>} Raw SOS alerts
   */
  async fetchAlerts() {
    throw new Error('Method not implemented.');
  }

  /**
   * @returns {Promise<Array<Object>>} Raw Accident reports
   */
  async fetchReports() {
    throw new Error('Method not implemented.');
  }
}
