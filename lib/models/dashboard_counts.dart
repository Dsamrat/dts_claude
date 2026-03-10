class DashboardCounts {
  final int totalInvoicesToday;
  final int awaitingPayment;
  final int waitingForDelivery;
  final int pickingInProgress;
  final int picked;
  final int readyForLoading;
  final int loaded;
  final int dispatched;
  final int deliveryCompleted;
  final int brDelivered;
  final int customerCollection;
  final int courier;
  final int signOnlyCompleted;
  final int cancelled;
  final int hold;
  final int reschedule;
  final int signOnly;
  final int totalTripsToday;
  final int totalVehicles;
  final int runningVehicles;
  final int invoicesInTrips;

  DashboardCounts({
    required this.totalInvoicesToday,
    required this.awaitingPayment,
    required this.waitingForDelivery,
    required this.pickingInProgress,
    required this.picked,
    required this.readyForLoading,
    required this.loaded,
    required this.dispatched,
    required this.deliveryCompleted,
    required this.brDelivered,
    required this.customerCollection,
    required this.courier,
    required this.signOnlyCompleted,
    required this.cancelled,
    required this.hold,
    required this.reschedule,
    required this.signOnly,
    required this.totalTripsToday,
    required this.totalVehicles,
    required this.runningVehicles,
    required this.invoicesInTrips,
  });

  factory DashboardCounts.fromJson(Map<String, dynamic> json) {
    final d = json['data'] ?? json;
    return DashboardCounts(
      totalInvoicesToday: d['totalInvoicesToday'] ?? 0,
      awaitingPayment: d['awaitingPayment'] ?? 0,
      waitingForDelivery: d['waitingForDelivery'] ?? 0,
      pickingInProgress: d['pickingInProgress'] ?? 0,
      picked: d['picked'] ?? 0,
      readyForLoading: d['readyForLoading'] ?? 0,
      loaded: d['loaded'] ?? 0,
      dispatched: d['dispatched'] ?? 0,
      deliveryCompleted: d['deliveryCompleted'] ?? 0,
      brDelivered: d['brDelivered'] ?? 0,
      customerCollection: d['customerCollection'] ?? 0,
      courier: d['courier'] ?? 0,
      signOnlyCompleted: d['signOnlyCompleted'] ?? 0,
      cancelled: d['cancelled'] ?? 0,
      hold: d['hold'] ?? 0,
      reschedule: d['reschedule'] ?? 0,
      signOnly: d['signOnly'] ?? 0,
      totalTripsToday: d['totalTripsToday'] ?? 0,
      totalVehicles: d['totalVehicles'] ?? 0,
      runningVehicles: d['runningVehicles'] ?? 0,
      invoicesInTrips: d['invoicesInTrips'] ?? 0,
    );
  }
}
