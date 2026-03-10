// lib/widgets/invoice_item/invoice_item_config.dart

import 'package:flutter/material.dart';

import 'invoice_screen_type.dart';

class InvoiceItemConfig {
  /// Screen type to determine specific behaviors
  final InvoiceScreenType screenType;

  /// Index of the item in the list (required for CRM/Sales)
  final int? index;

  /// Current expanded index (for manual expansion in CRM/Sales)
  final int? expandedIndex;

  /// Callback when expansion state changes
  final void Function(int index)? onExpansionChanged;

  /// Sign PDF flag (for Sales screen)
  final int signPDF;

  /// Map to track sign updating state (for CRM)
  final Map<int, bool>? signUpdating;

  /// Callback to open map
  final void Function(double lat, double lng) onOpenMap;

  /// Callback for status popup (CRM only)
  final void Function(Map<String, dynamic> invoice, int index)?
  onOpenStatusPopup;

  /// Callback for delivery type popup (CRM only)
  final void Function(String? deliveryType, dynamic invoiceId, int index)?
  onOpenDeliveryTypePopup;

  /// Callback to toggle sign only (CRM only)
  final void Function(Map<String, dynamic> invoice, int index)?
  onToggleSignOnly;

  /// Callback for timeline navigation
  final void Function(Map<String, dynamic> invoice, int index)? onOpenTimeline;

  /// Callback for payment navigation
  final void Function(Map<String, dynamic> invoice)? onMakePayment;

  /// Callback for view payment navigation
  final void Function(Map<String, dynamic> invoice)? onViewPayment;

  const InvoiceItemConfig({
    required this.screenType,
    required this.onOpenMap,
    this.index,
    this.expandedIndex,
    this.onExpansionChanged,
    this.signPDF = 0,
    this.signUpdating,
    this.onOpenStatusPopup,
    this.onOpenDeliveryTypePopup,
    this.onToggleSignOnly,
    this.onOpenTimeline,
    this.onMakePayment,
    this.onViewPayment,
  });
}
