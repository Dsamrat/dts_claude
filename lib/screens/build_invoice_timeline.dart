import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import '../constants/common.dart';

Widget _buildTimelineTile(
  Map<String, dynamic> status,
  bool isFirst,
  bool isLast,
) {
  return TimelineTile(
    alignment: TimelineAlign.manual,
    lineXY: 0.1,
    isFirst: isFirst,
    isLast: isLast,
    indicatorStyle: IndicatorStyle(
      width: 20,
      color: secondaryTeal,
      padding: const EdgeInsets.all(6),
    ),
    beforeLineStyle: const LineStyle(color: primaryTeal, thickness: 2),
    endChild: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (status['invoice_status'] ?? 'Unknown')
                .replaceAll('\\n', '')
                .replaceAll('\n', ''),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: secondaryTeal,
            ),
          ),
          const SizedBox(height: 4),
          if (status['updatedBy'] != null)
            Text(
              status['updatedBy']!, // Use ! as we've checked for null
              style: const TextStyle(color: primaryTeal),
            ),
          if (status['trip_name'] != null)
            Text(
              status['trip_name']!,
              style: const TextStyle(fontSize: 12, color: primaryTeal),
            ),
          if (status['vehicle_info'] != null)
            Text(
              status['vehicle_info']!,
              style: const TextStyle(fontSize: 12, color: primaryTeal),
            ),
          if (status['driver_name'] != null)
            Text(
              status['driver_name']!,
              style: const TextStyle(fontSize: 12, color: primaryTeal),
            ),
          if (status['created_at'] != null)
            Text(
              status['created_at']!,
              style: const TextStyle(fontSize: 12, color: primaryTeal),
            ),
        ],
      ),
    ),
  );
}

Widget buildInvoiceTimeline(List<dynamic> itemStatus) {
  // Then in your builder:
  return ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: itemStatus.length,
    itemBuilder: (context, index) {
      final status = itemStatus[index];
      final isFirst = index == 0;
      final isLast = index == itemStatus.length - 1;
      return _buildTimelineTile(status, isFirst, isLast);
    },
  );
}
