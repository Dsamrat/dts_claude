import 'package:flutter/material.dart';
import 'package:dts/widgets/navbar.dart';
import 'package:dts/screens/build_invoice_timeline.dart';
import '../services/invoice_service.dart';
import '../utils/dialogs.dart';

class CRMInvoiceTimeLine extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final int index;

  const CRMInvoiceTimeLine({
    super.key,
    required this.invoice,
    required this.index,
  });

  @override
  State<CRMInvoiceTimeLine> createState() => _CRMInvoiceTimeLineState();
}

class _CRMInvoiceTimeLineState extends State<CRMInvoiceTimeLine> {
  List<dynamic> itemStatus = [];
  bool isLoading = true;
  final InvoiceService _invoiceService = InvoiceService();

  @override
  void initState() {
    super.initState();
    fetchInvoiceStatus();
  }

  Future<void> fetchInvoiceStatus() async {
    try {
      final response = await _invoiceService.getInvoiceStatus(
        invoiceId: widget.invoice['invoice_id'],
      );

      setState(() {
        itemStatus = response;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);

      if (context.mounted) {
        await showErrorDialog(context, 'Failed to load invoice status: $e');
      }
    }
  }

  // ---------------------------------------------------------
  // PAGE UI
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(
        title: "${widget.invoice['doc_num'] ?? 'Invoice'}",
        backButton: true,
      ),
      extendBodyBehindAppBar: true,
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : itemStatus.isEmpty
              ? const Center(
                child: Text(
                  "No timeline data available.",
                  style: TextStyle(fontSize: 16),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: buildInvoiceTimeline(itemStatus),
              ),
    );
  }
}
//