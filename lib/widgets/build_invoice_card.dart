import 'package:dts/screens/expedition_screen.dart';
import 'package:dts/screens/invoice_page.dart';
import 'package:dts/screens/invoice_sign_operation.dart';
import 'package:dts/widgets/pdf_widgets/delivery_type_icon.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/common.dart';
import '../screens/trip_list_screen.dart';
import '../screens/view_payment_form.dart';
import 'build_flag.dart';

import 'hold_cancel_info.dart';
import 'package:dts/utils/string_extensions.dart';

void _openMap(double? latitude, double? longitude) async {
  debugPrint('build invoice $latitude');
  if (latitude == null || longitude == null) return;

  final Uri googleUrl = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
  );
  if (await canLaunchUrl(googleUrl)) {
    await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
  }
}

IconData _getSignIcon(int? signOnly) {
  return signOnly == 1 ? Icons.aod_outlined : Icons.app_blocking_outlined;
}

Color _getSignColor(int? signOnly) {
  return signOnly == 1 ? Colors.red : Colors.grey;
}

String getConfirmMessage(int? signOnly) {
  return signOnly == 1
      ? 'Confirm to remove sign-only?'
      : 'Confirm to mark as sign-only?';
}

Future<bool> showConfirmDialog(BuildContext context, String message) async {
  return await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirmation'),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes'),
                ),
              ],
            ),
      ) ??
      false;
}

Widget buildInvoiceCard(
  invoice, // Ensure the type is Invoice
  BuildContext context, {
  required String screen,
  VoidCallback? onTap,
  VoidCallback? onToggleSignOnly,
  /*VoidCallback? onToggleHold,
  VoidCallback? onToggleCancel,*/
  bool wrapWithCard = true,
  bool isExpanded = false,
  required Map<int, bool> signUpdating,
  // You might need to manage this state at a higher level
}) {
  // Check if the invoice is cancelled
  final cardBGColor = getInvoiceCardBGColor(
    invoiceCurrentStatus: invoice!.invoiceCurrentStatus,
    holdStatus: invoice!.holdStatus,
    defaultColor: Colors.white, // Or Colors.white
  );
  final isDisabled = isInvoiceDisabled(
    invoice!.invoiceCurrentStatus,
    invoice.holdStatus,
    invoice.deliveryType,
  );
  final bool isDeliveryCompleted =
      invoice.invoiceCurrentStatus == 7 && invoice.deliveryRemarks != null;

  /*final bool canToggle =
      (invoice.signOnly == 1 &&
          (invoice.invoiceCurrentStatus == 5 ||
              invoice.invoiceCurrentStatus == 6)) ||
      (invoice.signOnly == 0 && invoice.invoiceCurrentStatus == 1);*/
  final bool isVisible =
      invoice.invoiceCurrentStatus != null &&
      ((invoice.signOnly == 1 &&
              (invoice.invoiceCurrentStatus == 5 ||
                  invoice.invoiceCurrentStatus == 6)) ||
          (invoice.signOnly == 0 && invoice.invoiceCurrentStatus == 1));

  // 2. This controls if the button is INTERACTIVE (Disabled if on hold)
  final bool isHold = invoice.holdStatus == 9;
  final bool canToggle = !(invoice.signOnly == 0 && isHold);
  final DateTime createdAt = invoice.createdAt;
  final bool isWithin48Hours = DateTime.now().isBefore(
    createdAt.add(const Duration(hours: 48)),
  );
  // final bool isWithin48Hours = true;

  int targetTab = invoice.tripStatus;

  final content = InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Invoice Number and Status Flag
          Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      invoice.invoiceNum.toString(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: secondaryTeal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    buildFlag(
                      (invoice.invoiceStatus ?? 'Unknown').replaceAll(
                        '\\n',
                        '\n',
                      ),
                      invoice.statusColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (invoice.otherBranchDelivery == 1)
                (invoice.otherBranchName != null &&
                        invoice.otherBranchName!.isNotEmpty)
                    ? RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                        children: [
                          const TextSpan(text: 'Delivery From '), // regular
                          TextSpan(
                            text:
                                (invoice.otherBranchName as String?)
                                    ?.capitalize(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ), // bold
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    )
                    : const SizedBox.shrink(), // hide if null

              const SizedBox(height: 2),
              if (invoice.customerName.isNotEmpty) // Simplified condition
                Text(
                  (invoice.customerName as String?)?.toTitleCase() ?? '',
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (invoice.customerLatitude != null &&
                  invoice.customerLongitude != null &&
                  screen == 'HomeScreen')
                GestureDetector(
                  onTap: () {
                    final latString = invoice.customerLatitude;
                    final lngString = invoice.customerLongitude;
                    final lat =
                        (latString is String)
                            ? double.tryParse(latString)
                            : latString?.toDouble();
                    final lng =
                        (lngString is String)
                            ? double.tryParse(lngString)
                            : lngString?.toDouble();

                    if (lat != null && lng != null) {
                      _openMap(lat, lng);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Location not available")),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      // Build text only if there’s something to show
                      if ((invoice.customerDistance != null &&
                              invoice.customerDistance.toString().isNotEmpty &&
                              invoice.customerDistance
                                      .toString()
                                      .toLowerCase() !=
                                  'unknown') ||
                          (invoice.subLocality != null &&
                              invoice.subLocality.toString().isNotEmpty))
                        Text(
                          [
                            // if distance exists and not 'unknown'
                            if (invoice.customerDistance != null &&
                                invoice.customerDistance
                                    .toString()
                                    .isNotEmpty &&
                                invoice.customerDistance
                                        .toString()
                                        .toLowerCase() !=
                                    'unknown')
                              invoice.customerDistance.toString(),
                            // if sublocality exists
                            if (invoice.subLocality != null &&
                                invoice.subLocality.toString().isNotEmpty)
                              invoice.subLocality.toString(),
                          ].join(' • '), // combines them nicely
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        )
                      else
                        const Text(
                          "No location info",
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
              if (screen == 'HomeScreen')
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sales Person & Created By Row 👇
                    if ((invoice.displaySalesRep != null &&
                            invoice.displaySalesRep
                                .toString()
                                .trim()
                                .isNotEmpty) ||
                        (invoice.displayCreatedBy != null &&
                            invoice.displayCreatedBy
                                .toString()
                                .trim()
                                .isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Row(
                          children: [
                            if (invoice.displaySalesRep != null &&
                                invoice.displaySalesRep
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                              const Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Sales: ${invoice.displaySalesRep}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],

                            if (invoice.displaySalesRep != null &&
                                invoice.displaySalesRep
                                    .toString()
                                    .trim()
                                    .isNotEmpty &&
                                invoice.displayCreatedBy != null &&
                                invoice.displayCreatedBy
                                    .toString()
                                    .trim()
                                    .isNotEmpty)
                              const SizedBox(width: 8),

                            if (invoice.displayCreatedBy != null &&
                                invoice.displayCreatedBy
                                    .toString()
                                    .trim()
                                    .isNotEmpty) ...[
                              const Icon(
                                Icons.badge,
                                size: 14,
                                color: Colors.black87,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'By: ${invoice.displayCreatedBy}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              const SizedBox(
                height: 2,
              ), // Added a small space after customer name
              // 3. eComOrderID
              if (invoice.eComOrderID != null && invoice.eComOrderID.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text: 'Order ID: ',
                        style: TextStyle(
                          // fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                      ),
                      TextSpan(
                        text: '${invoice.eComOrderID}',
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
              const Icon(
                Icons.calendar_month,
                size: 18,
                color: secondaryTeal,
                // weight: 900,
              ),
              const SizedBox(width: 4),
              Text(
                invoice.docCreatedAt,
                style: const TextStyle(
                  fontSize: 14,
                  // fontWeight: FontWeight.bold,
                  color: secondaryTeal,
                ),
              ),
              const SizedBox(width: 16), // space between the two dates
              // Expected Delivery Time
              if (invoice.expectedDeliveryTime != null &&
                  invoice.expectedDeliveryTime.isNotEmpty) ...[
                expectedDelivery(size: 18),
                const SizedBox(width: 4),
                Text(
                  invoice.expectedDeliveryTime,
                  style: const TextStyle(
                    fontSize: 14,
                    // fontWeight: FontWeight.bold,
                    color: secondaryTeal,
                  ),
                ),
              ],
            ],
          ),
          if (invoice.delRemarks != null && invoice.delRemarks.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.message, size: 18, color: secondaryTeal),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    invoice.delRemarks ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: secondaryTeal,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: null,
                    softWrap: true,
                  ),
                ),
              ],
            ),

          // 2. customerName
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ===== Left Side: Flags, Trip, Status Icons =====
              Expanded(
                child: Wrap(
                  spacing: 4.0,
                  runSpacing: 4.0,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // ===== Hard Copy & COD Flags =====
                    if (invoice.hardCopy == '1') buildFlag('H', Colors.orange),
                    if (invoice.codFlag == '1') buildFlag('COD', Colors.green),
                    (invoice.codFlag == '1' &&
                            (invoice.deliveryType == 'Customer Collection' ||
                                invoice.deliveryType == 'Courier') &&
                            (invoice.salesType == 'Regular' ||
                                invoice.salesType == 'e-Store' ||
                                invoice.salesType == 'Cash Counter') &&
                            invoice.paymentStatus != 'Unpaid')
                        ? buildFlag(
                          invoice.paymentStatus,
                          invoice.paymentStatusColor,
                        )
                        : (screen == 'HomeScreen' &&
                            invoice.codFlag == '1' &&
                            invoice.paymentStatus != 'Unpaid')
                        ? buildFlag(
                          invoice.paymentStatus,
                          invoice.paymentStatusColor,
                        )
                        : const SizedBox.shrink(),

                    // ===== Delivery Type Icon =====
                    if (invoice.expressFlag?.toLowerCase() == 'exp')
                      expressDelivery,
                    deliveryTypeIcon(
                      context,
                      invoice.deliveryType,
                      invoice.deliverySalesPerson,
                    ),

                    if ((invoice.issueDuringDelivery ?? '').isNotEmpty &&
                        screen == 'HomeScreen')
                      InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  title: Row(
                                    children: const [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Issue During Delivery',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Text(
                                    invoice.issueDuringDelivery ??
                                        'No issue details available',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        },
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: const [
                            Icon(
                              Icons.local_shipping,
                              size: 30,
                              color: Colors.amber,
                            ),
                            Icon(Icons.error, size: 18, color: Colors.red),
                          ],
                        ),
                      ),

                    if (invoice.otherBranchDelivery == 1)
                      otherBranchDelivery(size: 20, color: Colors.purpleAccent),

                    // ===== Cancelled or Hold Icons =====
                    HoldCancelInfo(
                      invoiceCurrentStatus: invoice.invoiceCurrentStatus,
                      holdStatus: invoice.holdStatus,
                      holdAt: invoice.holdAt,
                      holdReason: invoice.holdReason,
                      holdReschedule: invoice.holdReschedule,
                    ),
                    // ===== Sign Only Icon / Arrow =====
                    if (invoice.signOnly == 1)
                      buildFlag('Sign Only', Colors.red),
                  ],
                ),
              ),

              // ===== Right Side: PDF Icons =====
              Wrap(
                spacing: 1.0,
                children: [
                  ...invoice.pdfs.map((pdf) {
                    final linkToOpen =
                        pdf.signedPdfLink != null &&
                                pdf.signedPdfLink!.isNotEmpty
                            ? pdf.signedPdfLink
                            : pdf.pdfLink;

                    return InkWell(
                      onTap: () {
                        debugPrint(invoice.codFlag.toString());
                        codFlag:
                        int.tryParse(invoice.codFlag.toString());

                        if (linkToOpen != null && linkToOpen.isNotEmpty) {
                          //AS PER TERM BUT CUSTOMER COLLECTION
                          if (invoice.codFlag == '0' &&
                                  invoice.deliveryType ==
                                      'Customer Collection' ||
                              invoice.deliveryType == 'Courier') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => InvoiceSignOperation(
                                      invoiceId: invoice.id,
                                      customerId: invoice.customerId,
                                      pdfId: pdf.pdfId,
                                      resolvedDocNum: pdf.resolvedDocNum,
                                      pdfLink: linkToOpen,
                                      signedPdfLink: pdf.signedPdfLink,
                                    ),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => InvoicePage(
                                      codFlag: int.tryParse(
                                        invoice.codFlag.toString(),
                                      ),
                                      pdfLink: linkToOpen,
                                      docType: pdf.docType,
                                      resolvedDocNum:
                                          pdf.resolvedDocNum, // For title
                                    ),
                              ),
                            );
                          }
                        }
                      },

                      child: Tooltip(
                        message:
                            pdf.signedPdfLink != null &&
                                    pdf.signedPdfLink!.isNotEmpty
                                ? 'Signed ${pdf.docType}'
                                : 'Unsigned ${pdf.docType}',
                        child: Icon(
                          pdf.docType == 'Invoice'
                              ? Icons.request_quote
                              : Icons.description,
                          color:
                              pdf.signedPdfLink != null &&
                                      pdf.signedPdfLink!.isNotEmpty
                                  ? Colors.blue
                                  : Colors.red,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                  if (screen == 'HomeScreen' && isDeliveryCompleted) ...[
                    // const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        showInfoDialog(
                          context: context,
                          title: 'Closing Remarks',
                          message: invoice.deliveryRemarks,
                        );
                      },
                      child: const Icon(
                        Icons.info_outline,
                        size: 30,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                  // ===== Trip Icons =====
                  if ((invoice.invoiceStatus == 'Ready for Loading' ||
                          (invoice.signOnly == 1 &&
                              invoice.invoiceStatus == 'Loaded')) &&
                      invoice.tripID == 0 &&
                      invoice.deliveryType != 'Customer Collection' &&
                      invoice.deliveryType != 'Courier')
                    // IconButton(icon: Icon(Icons.car_crash), onPressed: () {}),
                    if (isDisabled)
                      const SizedBox.shrink()
                    else
                      (invoice.actionAllowed == 0)
                          ? const SizedBox.shrink()
                          : Tooltip(
                            message: 'Create Trip',
                            child: InkWell(
                              onTap: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TripListScreen(),
                                  ),
                                );
                              },
                              child: const Icon(
                                Icons.car_crash,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                  if (invoice.tripID > 0 &&
                      invoice.invoiceTrip != null &&
                      isWithin48Hours) // Ensure invoiceTrip is not null
                    Tooltip(
                      message: 'Trip Created ',
                      child: InkWell(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => ExpeditionScreen(
                                    highlightTripID: invoice.tripID,
                                    initialTabIndex: targetTab,
                                  ),
                            ),
                          );
                        },
                        child: const Icon(Icons.car_crash, color: Colors.green),
                      ),
                    ),

                  if (screen == 'HomeScreen' && isVisible) ...[
                    const SizedBox(width: 3),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap:
                            (signUpdating[invoice.id] == true || !canToggle)
                                ? null
                                : () async {
                                  final confirm = await showConfirmDialog(
                                    context,
                                    getConfirmMessage(invoice.signOnly),
                                  );

                                  if (confirm) {
                                    onToggleSignOnly!();
                                  }
                                },

                        child:
                            signUpdating[invoice.id] == true
                                ? SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : Icon(
                                  _getSignIcon(invoice.signOnly),
                                  color: _getSignColor(invoice.signOnly),
                                  size: 28,
                                ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (invoice.codStatus && screen == 'HomeScreen')
            Align(
              alignment: Alignment.centerLeft, // or .centerRight if needed
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ViewPaymentForm(
                            invoice: {
                              'doc_num': invoice.invoiceNum,
                              'pmt_received': invoice.pmtReceived,
                              'pmt_option': invoice.pmtOption,
                              'pmt_received_by': invoice.pmtReceivedBy,
                              'amount': invoice.pmtAmount,
                              'payment_mode': invoice.pmtMode,
                              'cheque_number': invoice.chequeNumber,
                              'ref_id': invoice.refId,
                              'pmt_received_at': invoice.pmtReceivedAt,
                            },
                          ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt, color: Colors.blue),
                label: const Text(
                  'View Payment',
                  style: TextStyle(color: Colors.blue),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: Size(0, 0), // ✅ reduces default button height
                  // animationDuration: 5,
                ),
              ),
            ),

          // PDF icons on left side and COD, H flag on right side (ALL IN ONE ROW)
        ],
      ),
    ),
  );

  if (wrapWithCard) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      child: Card(
        color: cardBGColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 4,
        child: content,
      ),
    );
  } else {
    // return content;
    return Container(
      color: cardBGColor, // Apply background color without padding
      child: content,
    );
  }
}
