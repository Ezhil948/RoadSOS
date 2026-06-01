class SosStatus {
  final int? alertId;
  final String status;
  final bool isDispatched;
  final String? officerBadge;
  final double? officerDistanceKm;
  final String? cancellationReason;

  SosStatus({
    this.alertId,
    required this.status,
    required this.isDispatched,
    this.officerBadge,
    this.officerDistanceKm,
    this.cancellationReason,
  });

  bool get isResolved => 
      status == 'resolved' || 
      status == 'false_alarm' || 
      status == 'cancelled' || 
      status == 'cancelled_by_citizen';
      
  bool get isPoliceCancelled => status == 'cancelled_by_police';
}
