class AssignedVehicle {
  final int asId;
  final int asVehicleId;
  final int asDriverId;
  final String vehicle;
  final String driver;
  final String associateDriverNames;
  final List<int> asAssociateDriver;

  AssignedVehicle({
    required this.asId,
    required this.asVehicleId,
    required this.asDriverId,
    required this.vehicle,
    required this.driver,
    required this.associateDriverNames,
    required this.asAssociateDriver,
  });

  factory AssignedVehicle.fromJson(Map<String, dynamic> json) {
    return AssignedVehicle(
      asId: json['as_id'],
      asVehicleId: json['as_vehicle_id'],
      asDriverId: json['as_driver_id'],
      vehicle: json['vehicle'],
      driver: json['driver'],
      associateDriverNames: json['associate_driver_names'] ?? '',
      asAssociateDriver: List<int>.from(json['as_associate_driver'] ?? []),
    );
  }
}
