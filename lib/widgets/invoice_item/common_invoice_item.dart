// lib/widgets/invoice_item/common_invoice_item.dart

import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/material.dart';

import '../../constants/common.dart';
import '../build_flag.dart';
import '../common_pdf_icon.dart';
import '../hold_cancel_info.dart';
import '../pdf_widgets/delivery_type_icon.dart';
import 'invoice_item_config.dart';
import 'invoice_screen_type.dart';
// Import your other dependencies...

class CommonInvoiceItem extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final InvoiceItemConfig config;

  const CommonInvoiceItem({
    super.key,
    required this.invoice,
    required this.config,
  });

  bool get _isDisabled {
    switch (config.screenType) {
      case InvoiceScreenType.accounts:
        return isInvoiceDisabled(
          invoice['invoice_status_int'],
          invoice['holdStatus'],
          'test',
        );
      case InvoiceScreenType.crm:
      case InvoiceScreenType.sales:
        return false;
    }
  }

  bool get _isExpanded {
    if (config.screenType == InvoiceScreenType.accounts) {
      return false; // Handled by ExpansionTile internally
    }
    return config.expandedIndex == config.index;
  }

  bool get _canToggleSign {
    return (invoice['sign_only'] == 1 &&
            (invoice['invoice_status_int'] == 5 ||
                invoice['invoice_status_int'] == 6)) ||
        (invoice['sign_only'] == 0 && invoice['invoice_status_int'] == 1);
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: getInvoiceCardBGColor(
          invoiceCurrentStatus: invoice['invoice_status_int'],
          holdStatus: invoice['holdStatus'],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child:
          config.screenType == InvoiceScreenType.accounts
              ? _buildWithExpansionTile(context, items)
              : _buildWithManualExpansion(context, items),
    );
  }

  /// Build using ExpansionTile (Accounts screen)
  Widget _buildWithExpansionTile(BuildContext context, List<dynamic> items) {
    return ExpansionTile(
      title: _buildHeaderContent(context, showArrow: false),
      subtitle: _buildSubtitleContent(context),
      children: [_buildExpandedContent(items)],
    );
  }

  /// Build using manual GestureDetector expansion (CRM/Sales screens)
  Widget _buildWithManualExpansion(BuildContext context, List<dynamic> items) {
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            if (config.index != null && config.onExpansionChanged != null) {
              config.onExpansionChanged!(config.index!);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderContent(context, showArrow: true),
                const SizedBox(height: 6),
                _buildCommonDetails(context),
                _buildFlagsAndActions(context),
                _buildPaymentSection(context),
              ],
            ),
          ),
        ),
        if (_isExpanded) _buildExpandedContent(items),
      ],
    );
  }

  /// Common header with doc_num and status
  Widget _buildHeaderContent(BuildContext context, {required bool showArrow}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              invoice['doc_num'] ?? 'Invoice',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: secondaryTeal,
              ),
            ),
            Row(
              children: [
                buildFlag(
                  (invoice['invoice_status'] ?? 'Unknown').replaceAll(
                    '\\n',
                    '\n',
                  ),
                  getStatusColor(invoice['invoice_status_int']),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 28,
                    color: Colors.black54,
                  ),
                ],
              ],
            ),
          ],
        ),
        if (config.screenType == InvoiceScreenType.accounts) ...[
          _buildCommonDetails(context),
        ],
      ],
    );
  }

  /// Common details section (branch, customer, location, dates, etc.)
  Widget _buildCommonDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Branch delivery info
        if (invoice['other_branch_del'] == 1) _buildBranchDeliveryInfo(),

        const SizedBox(height: 4),

        // Customer name
        _buildCustomerName(),

        // Location info
        if (invoice['customer_latitude'] != null &&
            invoice['customer_longitude'] != null)
          _buildLocationRow(context),

        // Sales person & Created by
        _buildSalesCreatedByRow(),

        // Order ID
        if (invoice['order_id'] != null && invoice['order_id'].isNotEmpty)
          _buildOrderId(),

        // Dates row
        _buildDatesRow(),

        // Remarks
        if (invoice['del_remarks'] != null && invoice['del_remarks'].isNotEmpty)
          _buildRemarksRow(),
      ],
    );
  }

  Widget _buildBranchDeliveryInfo() {
    if (invoice['del_from_branch_name'] != null &&
        invoice['del_from_branch_name']!.isNotEmpty) {
      return RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: Colors.black87),
          children: [
            const TextSpan(text: 'Delivery From '),
            TextSpan(
              text: (invoice['del_from_branch_name'] as String?)?.capitalize(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCustomerName() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (invoice['customer_name']?.isNotEmpty == true)
          Expanded(
            child: Text(
              (invoice['customer_name'] as String?)?.toTitleCase() ?? '',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  Widget _buildLocationRow(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final latString = invoice['customer_latitude'];
        final lngString = invoice['customer_longitude'];
        final lat =
            (latString is String)
                ? double.tryParse(latString)
                : latString?.toDouble();
        final lng =
            (lngString is String)
                ? double.tryParse(lngString)
                : lngString?.toDouble();

        if (lat != null && lng != null) {
          config.onOpenMap(lat, lng);
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
          _buildLocationText(),
        ],
      ),
    );
  }

  Widget _buildLocationText() {
    final hasDistance =
        invoice['cus_distance'] != null &&
        invoice['cus_distance'].toString().isNotEmpty &&
        invoice['cus_distance'].toString().toLowerCase() != 'unknown';
    final hasSubLocality =
        invoice['subLocality'] != null &&
        invoice['subLocality'].toString().isNotEmpty;

    if (hasDistance || hasSubLocality) {
      return Text(
        [
          if (hasDistance) invoice['cus_distance'].toString(),
          if (hasSubLocality) invoice['subLocality'].toString(),
        ].join(' • '),
        style: const TextStyle(fontSize: 14, color: Colors.blue),
      );
    }
    return const Text(
      "No location info",
      style: TextStyle(fontSize: 14, color: Colors.grey),
    );
  }

  Widget _buildSalesCreatedByRow() {
    final hasSalesRep =
        invoice['displaySalesRep'] != null &&
        invoice['displaySalesRep'].toString().trim().isNotEmpty;
    final hasCreatedBy =
        invoice['displayCreatedBy'] != null &&
        invoice['displayCreatedBy'].toString().trim().isNotEmpty;

    if (!hasSalesRep && !hasCreatedBy) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          if (hasSalesRep) ...[
            const Icon(Icons.person, size: 14, color: Colors.teal),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Sales: ${invoice['displaySalesRep']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (hasSalesRep && hasCreatedBy) const SizedBox(width: 8),
          if (hasCreatedBy) ...[
            const Icon(Icons.badge, size: 14, color: Colors.black87),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'By: ${invoice['displayCreatedBy']}',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderId() {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Order ID: ',
            style: TextStyle(color: secondaryTeal),
          ),
          TextSpan(
            text: '${invoice['order_id']}',
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesRow() {
    return Row(
      children: [
        const Icon(Icons.calendar_month, size: 18, color: secondaryTeal),
        const SizedBox(width: 4),
        Text(
          invoice['doc_created_at'] ?? '',
          style: const TextStyle(fontSize: 14, color: secondaryTeal),
        ),
        const SizedBox(width: 2),
        if (invoice['expectedDeliveryTime'] != null &&
            invoice['expectedDeliveryTime'].isNotEmpty) ...[
          expectedDelivery(size: 18),
          const SizedBox(width: 4),
          Text(
            invoice['expectedDeliveryTime'],
            style: const TextStyle(fontSize: 14, color: secondaryTeal),
          ),
        ],
      ],
    );
  }

  Widget _buildRemarksRow() {
    return Row(
      children: [
        const Icon(Icons.message, size: 18, color: secondaryTeal),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            invoice['del_remarks'] ?? '',
            style: const TextStyle(fontSize: 14, color: secondaryTeal),
            maxLines: null,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  /// Flags and action icons section
  Widget _buildFlagsAndActions(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: _buildFlags(context)),
        _buildActionIcons(context),
      ],
    );
  }

  Widget _buildFlags(BuildContext context) {
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (invoice['hard_copy'] == 1) buildFlag('H', Colors.orange),
        if (invoice['cod_flag'] == 1) buildFlag('COD', Colors.green),
        if (invoice['sign_only'] == 1) buildFlag('Sign Only', Colors.red),
        if (invoice['expressFlag']?.toLowerCase() == 'exp') expressDelivery,
        deliveryTypeIcon(
          context,
          invoice['delivery_type'],
          invoice['deliverySalesPerson'],
        ),
        HoldCancelInfo(
          invoiceCurrentStatus: invoice['invoice_status_int'],
          holdStatus: invoice['holdStatus'],
          holdAt: invoice['holdAt'],
          holdReason: invoice['holdReason'],
          holdReschedule: invoice['holdReschedule'],
        ),
        if (invoice['cod_flag'] == 1 &&
            invoice['delivery_type'] != null &&
            (invoice['delivery_type'] == 'Customer Collection' ||
                invoice['delivery_type'] == 'Courier'))
          buildFlag(
            invoice['payment_status'],
            parseColor(invoice['payment_status_color']),
          ),
        if (invoice['other_branch_del'] == 1)
          otherBranchDelivery(size: 20, color: Colors.purpleAccent),
      ],
    );
  }

  Widget _buildActionIcons(BuildContext context) {
    return Wrap(
      spacing: 1.0,
      runSpacing: 1.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // PDF Icons (common to all)
        CommonPdfIcons(
          context: context,
          invoice: invoice,
          startKm: 0,
          isDisabled: _isDisabled,
          screenType: _getPdfIconScreenType(),
          signPDF: config.signPDF,
        ),

        // CRM-specific icons
        if (config.screenType == InvoiceScreenType.crm) ...[
          _buildCrmStatusIcon(context),
          _buildCrmDeliveryTypeIcon(context),
        ],

        // Timeline icon (CRM and Sales)
        if (config.screenType != InvoiceScreenType.accounts)
          _buildTimelineIcon(context),

        // Sign toggle (CRM only)
        if (config.screenType == InvoiceScreenType.crm && _canToggleSign)
          _buildSignToggleIcon(context),
      ],
    );
  }

  PdfIconScreenType _getPdfIconScreenType() {
    switch (config.screenType) {
      case InvoiceScreenType.accounts:
        return PdfIconScreenType.accounts;
      case InvoiceScreenType.crm:
        return PdfIconScreenType.crm;
      case InvoiceScreenType.sales:
        return PdfIconScreenType.sales;
    }
  }

  Widget _buildCrmStatusIcon(BuildContext context) {
    if (invoice['invoice_status_int'] == null ||
        (invoice['invoice_status_int'] > 4 &&
            invoice['invoice_status_int'] != 11)) {
      return const SizedBox.shrink();
    }

    final iconData = _getStatusIcon(invoice['invoice_status_int']);
    return InkWell(
      onTap: () {
        if (config.onOpenStatusPopup != null && config.index != null) {
          config.onOpenStatusPopup!(invoice, config.index!);
        }
      },
      child: Icon(
        iconData,
        size: 28,
        color: (iconData == Icons.no_encryption) ? Colors.blue : Colors.red,
      ),
    );
  }

  Widget _buildCrmDeliveryTypeIcon(BuildContext context) {
    if (invoice['invoice_status_int'] == null ||
        (invoice['invoice_status_int'] > 4 &&
            invoice['invoice_status_int'] != 11) ||
        invoice['trip_id'] != 0) {
      return const SizedBox.shrink();
    }

    final iconData = _getDeliveryTypeIcon(invoice['delivery_type']);
    return InkWell(
      onTap: () {
        if (config.onOpenDeliveryTypePopup != null && config.index != null) {
          config.onOpenDeliveryTypePopup!(
            invoice['delivery_type'],
            invoice['invoice_id'],
            config.index!,
          );
        }
      },
      child: Icon(
        iconData,
        size: 28,
        color: (iconData == Icons.fire_truck) ? Colors.blue : Colors.red,
      ),
    );
  }

  Widget _buildTimelineIcon(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (config.onOpenTimeline != null && config.index != null) {
          config.onOpenTimeline!(invoice, config.index!);
        }
      },
      child: const Icon(Icons.access_time, color: Colors.green, size: 28),
    );
  }

  Widget _buildSignToggleIcon(BuildContext context) {
    final invoiceId = int.tryParse(invoice['invoice_id'].toString()) ?? 0;
    final isUpdating = config.signUpdating?[invoiceId] == true;

    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: GestureDetector(
        onTap:
            (isUpdating || !_canToggleSign)
                ? null
                : () {
                  if (config.onToggleSignOnly != null && config.index != null) {
                    config.onToggleSignOnly!(invoice, config.index!);
                  }
                },
        child:
            isUpdating
                ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(
                  _getSignIcon(invoice['sign_only']),
                  color: _getSignColor(invoice['sign_only']),
                  size: 28,
                ),
      ),
    );
  }

  /// Subtitle content (for ExpansionTile in Accounts)
  Widget _buildSubtitleContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildFlagsAndActions(context), _buildPaymentSection(context)],
    );
  }

  /// Payment section
  Widget _buildPaymentSection(BuildContext context) {
    final showPayment = _shouldShowPaymentSection();
    if (!showPayment) return const SizedBox.shrink();

    return Row(
      children: [
        if (invoice['cod_status'] == 0)
          TextButton.icon(
            onPressed:
                _isDisabled ? null : () => config.onMakePayment?.call(invoice),
            icon: Icon(
              Icons.receipt,
              color: _isDisabled ? Colors.grey : Colors.red,
            ),
            label: Text(
              'Update Payment Info.',
              style: TextStyle(color: _isDisabled ? Colors.grey : Colors.red),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          TextButton.icon(
            onPressed: () => config.onViewPayment?.call(invoice),
            icon: const Icon(Icons.receipt, color: Colors.blue),
            label: const Text(
              'View Payment',
              style: TextStyle(color: Colors.blue),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  bool _shouldShowPaymentSection() {
    switch (config.screenType) {
      case InvoiceScreenType.accounts:
        return invoice['cod_flag'] == 1;
      case InvoiceScreenType.crm:
        return false; // CRM doesn't show payment section
      case InvoiceScreenType.sales:
        return invoice['cod_flag'] == 1 && config.signPDF == 1;
    }
  }

  /// Expanded content with items
  Widget _buildExpandedContent(List<dynamic> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
          if (items.isNotEmpty)
            Column(
              children:
                  items
                      .map(
                        (item) => ListTile(
                          title: Text(item['item_name'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item['item_sku'] ?? ''}'),
                              Text('${item['item_sno'] ?? ''}'),
                              Text(
                                'Qty: ${item['item_qty'] ?? ''}',
                                style: const TextStyle(color: primaryTeal),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
            ),
          if (items.isEmpty)
            const Text(
              'No items in this invoice.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  // Helper methods for icons (move these from CRM screen)
  IconData _getStatusIcon(int? status) {
    // Your existing logic
    return Icons.no_encryption; // placeholder
  }

  IconData _getDeliveryTypeIcon(String? type) {
    // Your existing logic
    return Icons.fire_truck; // placeholder
  }

  IconData _getSignIcon(int? signOnly) {
    // Your existing logic
    return Icons.edit; // placeholder
  }

  Color _getSignColor(int? signOnly) {
    // Your existing logic
    return Colors.blue; // placeholder
  }
}
