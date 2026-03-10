import 'package:flutter/material.dart';

class TripStatusFlag extends StatelessWidget {
  final dynamic startKm;
  final dynamic endKm;

  const TripStatusFlag({Key? key, required this.startKm, required this.endKm})
    : super(key: key);

  String? _getTripStatus() {
    final bool hasStartKm = startKm != null && startKm != 0;
    final bool hasEndKm = endKm != null && endKm != 0;

    if (!hasStartKm && !hasEndKm) return 'Preparing';
    if (hasStartKm && !hasEndKm) return 'Dispatched';
    if (hasStartKm && hasEndKm) return 'Completed';
    return null;
  }

  Color _getColor(String status) {
    switch (status) {
      case 'Preparing':
        return Colors.yellow.shade800;
      case 'Dispatched':
        return Colors.orange.shade600;
      case 'Completed':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _getTripStatus();
    if (status == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _getColor(status),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
