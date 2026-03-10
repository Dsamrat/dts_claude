import 'package:flutter/material.dart';
// Import your page files
import '../screens/invoice_page.dart';
import '../screens/invoice_sign_page.dart';

/// Enum to identify which screen is using this widget
enum PdfIconScreenType { accounts, driver, crm, sales }

class CommonPdfIcons extends StatelessWidget {
  final BuildContext context;
  final Map<String, dynamic> invoice;
  final dynamic startKm;
  final bool isDisabled;
  final PdfIconScreenType screenType;
  final int? signPDF; // Only used for sales screen

  const CommonPdfIcons({
    super.key,
    required this.context,
    required this.invoice,
    required this.startKm,
    required this.isDisabled,
    required this.screenType,
    this.signPDF,
  });

  @override
  Widget build(BuildContext context) {
    return _buildPdfIcons();
  }

  Widget _buildPdfIcons() {
    List<Widget> pdfWidgets = [];

    final List<dynamic> pdfsData = (invoice['pdfs'] as List<dynamic>?) ?? [];

    if (pdfsData.isNotEmpty) {
      for (var pdfJson in pdfsData) {
        final String? docType = pdfJson['doc_type'] as String?;
        final String? pdfLink = pdfJson['pdf_link'] as String?;
        final String? signedPdfLink = pdfJson['signed_pdf_link'] as String?;
        final int? pdfId = pdfJson['pdf_id'] as int?;
        final String? linkToOpen =
            signedPdfLink?.isNotEmpty == true ? signedPdfLink : pdfLink;
        final bool canObtainSign = (pdfJson['canObtainSign'] ?? 1) == 1;

        if (linkToOpen?.isNotEmpty == true) {
          pdfWidgets.add(
            IgnorePointer(
              ignoring: isDisabled,
              child: InkWell(
                onTap:
                    () => _handleTap(
                      pdfJson,
                      linkToOpen!,
                      docType,
                      pdfId,
                      signedPdfLink,
                      canObtainSign,
                    ),
                child: _buildIcon(pdfJson, docType),
              ),
            ),
          );
        }
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          pdfWidgets.isNotEmpty
              ? pdfWidgets
              : [
                const Text(
                  'No PDFs',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
    );
  }

  /// Handles navigation based on screen type
  void _handleTap(
    Map<String, dynamic> pdfJson,
    String linkToOpen,
    String? docType,
    int? pdfId,
    String? signedPdfLink,
    bool canObtainSign,
  ) {
    final int startKiloMeter = _getStartKilometer();
    final String resolvedDocNum =
        pdfJson['resolved_doc_num']?.toString().trim() ?? '';

    switch (screenType) {
      case PdfIconScreenType.accounts:
        _navigateToSignPage(
          linkToOpen: linkToOpen,
          docType: docType,
          pdfJson: pdfJson,
          invoiceId: invoice['invoice_id'],
          pdfId: pdfId,
          startKiloMeter: startKiloMeter,
          signedPdfLink: signedPdfLink,
        );
        break;

      /*case PdfIconScreenType.driver:
        final invoiceId =
            pdfJson['getSign'] == 1
                ? invoice['invoice_id']
                : pdfJson['pdf_invoice_id'];
        _navigateToSignPage(
          linkToOpen: linkToOpen,
          docType: docType,
          pdfJson: pdfJson,
          invoiceId: invoiceId,
          pdfId: pdfId,
          startKiloMeter: startKiloMeter,
          signedPdfLink: signedPdfLink,
        );
        break;*/
      case PdfIconScreenType.driver:
        final invoiceId =
            pdfJson['getSign'] == 1
                ? invoice['invoice_id']
                : pdfJson['pdf_invoice_id'];

        if (canObtainSign) {
          _navigateToSignPage(
            linkToOpen: linkToOpen,
            docType: docType,
            pdfJson: pdfJson,
            invoiceId: invoiceId,
            pdfId: pdfId,
            startKiloMeter: startKiloMeter,
            signedPdfLink: signedPdfLink,
          );
        } else {
          _navigateToViewPage(
            linkToOpen: linkToOpen,
            docType: docType,
            resolvedDocNum: resolvedDocNum,
          );
        }
        break;

      case PdfIconScreenType.crm:
        _navigateToViewPage(
          linkToOpen: linkToOpen,
          docType: docType,
          resolvedDocNum: resolvedDocNum,
        );
        break;

      case PdfIconScreenType.sales:
        if (signPDF == 1) {
          _navigateToSignPage(
            linkToOpen: linkToOpen,
            docType: docType,
            pdfJson: pdfJson,
            invoiceId: invoice['invoice_id'],
            pdfId: pdfId,
            startKiloMeter: startKiloMeter,
            signedPdfLink: signedPdfLink,
          );
        } else {
          _navigateToViewPage(
            linkToOpen: linkToOpen,
            docType: docType,
            resolvedDocNum: resolvedDocNum,
          );
        }
        break;
    }
  }

  /// Navigate to InvoiceSignPage
  void _navigateToSignPage({
    required String linkToOpen,
    required String? docType,
    required Map<String, dynamic> pdfJson,
    required dynamic invoiceId,
    required int? pdfId,
    required int startKiloMeter,
    required String? signedPdfLink,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InvoiceSignPage(
              pdfLink: linkToOpen,
              docType: docType ?? '',
              invoiceNum: pdfJson['resolved_doc_num']?.toString() ?? 'N/A',
              invoiceId: invoiceId,
              customerId: invoice['customer_id'],
              cusLatitude: invoice['customer_latitude'],
              cusLongitude: invoice['customer_longitude'],
              pdfId: pdfId ?? 0,
              startKiloMeter: startKiloMeter,
              signedPdfLink: signedPdfLink,
              docLocation: invoice['doc_loc_id'],
            ),
      ),
    );
  }

  /// Navigate to InvoicePage (view only)
  void _navigateToViewPage({
    required String linkToOpen,
    required String? docType,
    required String resolvedDocNum,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => InvoicePage(
              codFlag: int.tryParse(invoice['cod_flag'].toString()),
              pdfLink: linkToOpen,
              docType: docType ?? '',
              resolvedDocNum: resolvedDocNum,
            ),
      ),
    );
  }

  /// Get start kilometer value
  int _getStartKilometer() {
    if (screenType == PdfIconScreenType.accounts ||
        screenType == PdfIconScreenType.sales) {
      return 10; // Default value for accounts and sales
    }
    return int.tryParse(startKm.toString()) ?? 0;
  }

  /// Build the PDF icon with tooltip
  Widget _buildIcon(Map<String, dynamic> pdfJson, String? docType) {
    final bool isSigned =
        pdfJson['signed_pdf_link'] != null &&
        pdfJson['signed_pdf_link']!.toString().isNotEmpty;

    return Tooltip(
      message: '${isSigned ? 'Signed' : 'Unsigned'} ${docType ?? ''}',
      child: Icon(
        docType == 'Invoice' ? Icons.request_quote : Icons.description,
        color:
            isDisabled
                ? Colors.grey
                : isSigned
                ? Colors.blue
                : Colors.red,
        size: 28,
      ),
    );
  }
}
