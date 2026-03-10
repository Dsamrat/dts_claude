import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/material.dart';

import '../../constants/common.dart';
import 'build_flag.dart';

class CommonCard extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const CommonCard({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              invoice['invoiceNum'].toString(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: secondaryTeal,
              ),
            ),
            buildFlag(
              (invoice['invoiceStatus'] ?? 'Unknown').replaceAll('\\n', '\n'),
              invoice['statusColor'],
            ),
          ],
        ),
        // Add other common elements here if needed
        const SizedBox(height: 2),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (invoice['customerName'].isNotEmpty) // Simplified condition
              Text(
                (invoice['customerName'] as String?)?.toTitleCase() ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(
              height: 2,
            ), // Added a small space after customer name
            // 3. eComOrderID
            if (invoice['eComOrderID'] != null &&
                invoice['eComOrderID'].isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Order ID: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: secondaryTeal,
                      ),
                    ),
                    TextSpan(
                      text: '${invoice['eComOrderID']}',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
          ],
        ),
        Row(
          children: [
            // Created At
            const Icon(Icons.calendar_month, size: 18, color: secondaryTeal),
            const SizedBox(width: 4),
            Text(
              invoice['docCreatedAt'],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: secondaryTeal,
              ),
            ),
            const SizedBox(width: 16), // space between the two dates
            // Expected Delivery Time
            if (invoice['expectedDeliveryTime'] != null &&
                invoice['expectedDeliveryTime'].isNotEmpty) ...[
              expectedDelivery(size: 18),
              const SizedBox(width: 4),
              Text(
                invoice['expectedDeliveryTime'],
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: secondaryTeal,
                ),
              ),
            ],
          ],
        ),
        if (invoice['delRemarks'] != null && invoice['delRemarks'].isNotEmpty)
          Row(
            children: [
              const Icon(Icons.message, size: 18, color: secondaryTeal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  invoice['delRemarks'] ?? '',
                  style: const TextStyle(fontSize: 14, color: secondaryTeal),
                  maxLines: null,
                  softWrap: true,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
