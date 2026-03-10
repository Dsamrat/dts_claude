import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/material.dart';

import '../constants/common.dart';

import '../widgets/navbar.dart';

class ViewPaymentForm extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const ViewPaymentForm({super.key, required this.invoice});

  @override
  State<ViewPaymentForm> createState() => _ViewPaymentFormState();
}

class _ViewPaymentFormState extends State<ViewPaymentForm> {
  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final String selectedDocNum = invoice['doc_num'] ?? '-';
    final String isPaymentReceived = invoice['pmt_received'];
    final String amountOption = invoice['pmt_option'] ?? '-';
    final String paymentReceivedBy = invoice['pmt_received_by'] ?? '';
    final String paymentReceivedAt = invoice['pmt_received_at'] ?? '';
    final String RefId = invoice['ref_id'] ?? '';
    final String amount =
        double.tryParse(invoice['amount'] ?? '0')?.toStringAsFixed(2) ?? '0.00';
    final String paymentMode = invoice['payment_mode'] ?? '-';
    final String? chequeNumber = invoice['cheque_number'];
    return Scaffold(
      appBar: Navbar(title: "View Payment Details", backButton: true),

      body: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    '${selectedDocNum}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: secondaryTeal,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildRow('Payment Option', isPaymentReceived),
                if (isPaymentReceived == 'Receive Payment' ||
                    isPaymentReceived == 'Receive in Advance') ...[
                  _buildRow('Amount Option', amountOption),
                  _buildRow('Amount', amount),
                  _buildRow('Payment Mode', paymentMode),
                  if (paymentMode.toLowerCase() == 'cheque')
                    _buildRow('Cheque Number', chequeNumber ?? '-')
                  else
                    const Divider(),
                  if (paymentReceivedBy.isNotEmpty)
                    _buildRow(
                      'Received By',
                      (paymentReceivedBy as String?)?.toTitleCase() ?? '',
                    ),
                  if (paymentReceivedAt.isNotEmpty)
                    _buildRow('Updated at', paymentReceivedAt),
                  if (RefId.isNotEmpty) _buildRow('ITR ID', RefId),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        // Use a Column to stack the Row and Divider vertically
        children: [
          Row(
            // Row for the label and value
            children: [
              // Space between icon and text
              Expanded(
                flex: 6,
                child: Text(
                  '$label:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: secondaryTeal,
                  ), // Added font size for clarity
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 16),
                ), // Added font size for clarity
              ),
            ],
          ),
          const Divider(), // This Divider will now correctly separate rows
        ],
      ),
    );
  }
}
