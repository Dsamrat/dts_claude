import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants/common.dart';

class HoldCancelInfo extends StatelessWidget {
  final int invoiceCurrentStatus;
  final int holdStatus;
  final String? holdAt;
  final String? holdReason;
  final String? holdReschedule;

  const HoldCancelInfo({
    Key? key,
    required this.invoiceCurrentStatus,
    required this.holdStatus,
    this.holdAt,
    this.holdReason,
    this.holdReschedule,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Only show button if canceled or on hold
    if (invoiceCurrentStatus != 8 && holdStatus != 9 && holdStatus != 10) {
      return const SizedBox.shrink();
    }
    final holdStatusIcon = getStatusIcon(
      invoiceCurrentStatus: invoiceCurrentStatus,
      holdStatus: holdStatus,
    );
    return InkWell(
      onTap: () {
        List<InlineSpan> messageSpans = [];

        if (invoiceCurrentStatus == 8) {
          messageSpans.addAll([
            const TextSpan(
              text: "Canceled at: ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: "${holdAt ?? '-'}\n"),
            const TextSpan(
              text: "Reason: ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: "${holdReason ?? '-'}\n"),
          ]);
        }
        if (holdStatus != 0) {
          final holdLabel = (holdStatus == 9) ? "Held at" : "Rescheduled at";
          messageSpans.addAll([
            TextSpan(
              text: "$holdLabel: ",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: "${holdAt ?? '-'}\n"),
            const TextSpan(
              text: "Reason: ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: "${holdReason ?? '-'}\n"),
          ]);

          // Reschedule time
          if (holdReschedule != null &&
              holdReschedule!.isNotEmpty &&
              holdReschedule != '-') {
            try {
              final parsedDate = DateTime.parse(
                holdReschedule!,
              ); // parse ISO 8601
              final formattedDate = DateFormat(
                "dd/MM/yyyy hh:mm a",
              ).format(parsedDate);
              messageSpans.addAll([
                const TextSpan(
                  text: "Reschedule Time: ",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: "$formattedDate\n"),
              ]);
            } catch (e) {
              // fallback in case of parsing error
              messageSpans.add(TextSpan(text: "$holdReschedule\n"));
            }
          }
        }

        showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Alert'),
                content: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 14),
                    children: messageSpans,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      },
      child: Icon(holdStatusIcon, color: Colors.red),
    );
  }
}
