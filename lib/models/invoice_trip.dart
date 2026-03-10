// lib/models/invoice_trip.dart
class InvoiceTrip {
  final int tripId;
  final String tripDate;
  final String tripName;
  final int vehicleId;
  final int driverId;
  final String? startKm;
  final String? endKm;
  final String? latitude;
  final String? longitude;
  final String? street;
  final String? subLocality;
  final String? locality;
  final String? administrativeArea;
  final String? postalCode;
  final String? country;
  final String createdAt;
  final String updatedAt;

  InvoiceTrip({
    required this.tripId,
    required this.tripDate,
    required this.tripName,
    required this.vehicleId,
    required this.driverId,
    this.startKm,
    this.endKm,
    this.latitude,
    this.longitude,
    this.street,
    this.subLocality,
    this.locality,
    this.administrativeArea,
    this.postalCode,
    this.country,
    required this.createdAt,
    required this.updatedAt,
  });

  factory InvoiceTrip.fromJson(Map<String, dynamic> json) {
    return InvoiceTrip(
      tripId: json['trip_id'] as int,
      tripDate: json['trip_date']?.toString() ?? '',
      tripName: json['trip_name']?.toString() ?? '',
      vehicleId: json['vehicle_id'] as int,
      driverId: json['driver_id'] as int,
      startKm: json['start_km']?.toString(),
      endKm: json['end_km']?.toString(),
      latitude: json['latitude']?.toString(),
      longitude: json['longitude']?.toString(),
      street: json['street']?.toString(),
      subLocality: json['subLocality']?.toString(),
      locality: json['locality']?.toString(),
      administrativeArea: json['administrativeArea']?.toString(),
      postalCode: json['postalCode']?.toString(),
      country: json['country']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}
