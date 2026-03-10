import 'PdfDetail.dart';
import 'package:flutter/material.dart';

import 'invoice_trip.dart';

class Invoice {
  final int id;
  final String invoiceNum;
  final String customerName;
  final String customerEmail;
  final int customerId;
  int deliveryFromBranchId;
  final String eComOrderID;
  final String hardCopy;
  final String codFlag;
  final bool codStatus;
  String invoiceStatus;
  final String delRemarks;
  int invoiceCurrentStatus;
  int signOnly;
  int tripID;
  int tripStatus;
  final String updatedAt;
  final DateTime createdAt;
  final String? otherBranchName;
  final String? deliverySalesPerson;
  int holdStatus;
  final String holdAt;
  String holdReason;
  final String holdReschedule;
  final String allPdfSigned;
  int branchId;
  final List<PdfDetail> pdfs;
  final String? pmtReceived;
  final String? pmtReceivedBy;
  final String? pmtOption;
  final String? pmtMode;
  final String? pmtAmount;
  final String? chequeNumber;
  final String? salesType;
  final String? expressFlag;
  String? deliveryType;
  String? refId;
  String? pmtReceivedAt;
  String? displayCreatedBy;
  String? displaySalesRep;
  String? customerLatitude;
  String? customerLongitude;
  String? customerDistance;
  String? subLocality;
  final int soId;
  final String docCreatedAt;
  String? expectedDeliveryTime;
  final InvoiceTrip? invoiceTrip; // Add this field
  final bool allItemLoaded;
  int actionAllowed;
  int otherBranchDelivery;
  String? awbNumber;
  double? courierCost;
  String? courierRemarks;
  String? courierUpdatedTime;
  String? courierUpdatedBy;
  String? issueDuringDelivery;
  String? deliveryRemarks;
  String? salesPerson;

  Invoice({
    required this.id,
    required this.invoiceNum,
    required this.customerName,
    required this.customerId,
    required this.deliveryFromBranchId,
    required this.customerEmail,
    required this.eComOrderID,
    required this.hardCopy,
    required this.codFlag,
    required this.codStatus,
    required this.invoiceStatus,
    required this.delRemarks,
    required this.invoiceCurrentStatus,
    required this.signOnly,
    required this.tripID,
    required this.tripStatus,
    required this.actionAllowed,
    required this.otherBranchDelivery,
    required this.updatedAt,
    required this.createdAt,
    required this.holdStatus,
    required this.holdAt,
    required this.holdReason,
    required this.holdReschedule,
    required this.allPdfSigned,
    required this.branchId,
    required this.pdfs, // New
    this.pmtReceived,
    this.pmtReceivedBy,
    this.pmtOption,
    this.pmtMode,
    this.pmtAmount,
    this.chequeNumber,
    this.otherBranchName,
    this.deliverySalesPerson,
    this.salesType,
    this.expressFlag,
    this.deliveryType,
    this.refId,
    this.pmtReceivedAt,
    this.displayCreatedBy,
    this.displaySalesRep,
    this.customerLatitude,
    this.customerLongitude,
    this.customerDistance,
    this.subLocality,
    required this.soId,
    required this.docCreatedAt,
    this.expectedDeliveryTime,
    this.invoiceTrip,
    required this.allItemLoaded,
    this.awbNumber,
    this.courierCost,
    this.courierRemarks,
    this.courierUpdatedTime,
    this.courierUpdatedBy,
    this.issueDuringDelivery,
    this.deliveryRemarks,
    this.salesPerson,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    List<PdfDetail> parsedPdfs =
        (json['pdfs'] as List<dynamic>?)
            ?.map((e) => PdfDetail.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    // Parse invoice_trip if it exists
    InvoiceTrip? parsedInvoiceTrip;
    if (json['invoice_trip'] != null) {
      parsedInvoiceTrip = InvoiceTrip.fromJson(
        json['invoice_trip'] as Map<String, dynamic>,
      );
    }
    return Invoice(
      id: json['id'] as int,
      invoiceNum: json['doc_num']?.toString() ?? '',
      allItemLoaded: json['allItemLoaded'],
      customerName: json['customer_name']?.toString() ?? '',
      customerEmail: json['customer_email']?.toString() ?? '',
      customerId: json['customer_id'],
      deliveryFromBranchId: json['del_from_branch_id'],
      eComOrderID: json['order_id']?.toString() ?? '',
      hardCopy: json['hard_copy']?.toString() ?? '0',
      codFlag: json['cod_flag']?.toString() ?? '0',
      codStatus: json['cod_status'] ?? 0,
      invoiceStatus: mapStatus(
        json['invoice_status'] is String
            ? int.tryParse(json['invoice_status']) ?? 0
            : json['invoice_status'] ?? 0,
      ),
      delRemarks: json['del_remarks']?.toString() ?? '',
      invoiceCurrentStatus: json['invoice_status'],
      signOnly: json['sign_only'],
      tripID: json['trip_id'],
      tripStatus: json['tripStatus'],
      actionAllowed: json['actionAllowed'],
      otherBranchDelivery: json['other_branch_del'],
      updatedAt: json['updated_at']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['created_at'].toString().replaceAll(' ', 'T'),
      ),
      otherBranchName: json['del_from_branch_name']?.toString() ?? '',
      deliverySalesPerson: json['deliverySalesPerson']?.toString() ?? '',
      holdStatus: json['holdStatus'],
      holdAt: json['holdAt']?.toString() ?? '',
      holdReason: json['holdReason']?.toString() ?? '',
      holdReschedule: json['holdReschedule']?.toString() ?? '',
      allPdfSigned: json['pdf_sign_status']?.toString() ?? 'unsigned',
      branchId: json['branch_id'] ?? 0,
      pdfs: parsedPdfs,
      pmtReceived: json['pmt_received']?.toString(),
      pmtReceivedBy: json['pmt_received_by']?.toString(),
      pmtOption: json['pmt_option']?.toString(),
      pmtMode: json['payment_mode']?.toString(),
      pmtAmount: json['amount']?.toString(),
      chequeNumber: json['cheque_number']?.toString(),
      salesType: json['sales_type']?.toString(),
      expressFlag: json['exp_flag']?.toString(),
      deliveryType: json['delivery_type']?.toString(),
      refId: json['ref_id']?.toString(),
      pmtReceivedAt: json['pmt_received_at']?.toString(),
      displayCreatedBy: json['displayCreatedBy']?.toString(),
      displaySalesRep: json['displaySalesRep']?.toString(),
      customerLatitude: json['cus_latitude']?.toString(),
      customerLongitude: json['cus_longitude']?.toString(),
      customerDistance: json['cus_distance']?.toString(),
      subLocality: json['subLocality']?.toString(),
      soId: json['som_id'],
      docCreatedAt: json['doc_created_at'],
      expectedDeliveryTime: json['expectedDeliveryTime']?.toString() ?? '',
      invoiceTrip: parsedInvoiceTrip,
      awbNumber: json['awb_number'],
      courierCost:
          json['courier_cost'] != null
              ? double.tryParse(json['courier_cost'].toString())
              : null,
      courierRemarks: json['courier_remarks'],
      courierUpdatedTime: json['courier_updated_time'],
      courierUpdatedBy: json['courier_updated_by'],
      issueDuringDelivery: json['issue_during_delivery'],
      deliveryRemarks: json['delivery_remarks'],
      salesPerson: json['salesRepName'],
    );
  }
  // 👇 Derived value
  String get paymentStatus {
    switch (pmtReceived?.toLowerCase()) {
      case 'receive payment':
        return 'Paid';
      case 'receive in advance':
        return 'Paid';
      case 'not paid':
        return 'Not Paid';
      case 'proceed without payment':
        return 'Proceed without payment';
      default:
        return 'Unpaid';
    }
  }

  Color get paymentStatusColor {
    switch (pmtReceived?.toLowerCase()) {
      case 'receive payment':
        return Colors.green;
      case 'receive in advance':
        return Colors.green;
      case 'not paid':
        return Colors.red;
      case 'proceed without payment':
        return Colors.blue;
      default:
        return Colors.yellow.shade800;
    }
  }

  static String mapStatus(int status) {
    switch (status) {
      case 1:
        return 'Waiting for Delivery';
      case 2:
        return 'Picking in Progress';
      case 3:
        return 'Picked';
      case 4:
        return 'Ready for Loading';
      case 5:
        return 'Loaded';
      case 6:
        return 'Dispatched';
      case 7:
        return 'Delivery Completed';
      case 8:
        return 'Canceled';
      case 11:
        return 'Awaiting Payment';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (invoiceCurrentStatus) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.teal;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.deepOrange;
      case 6:
        return Colors.green;
      case 7:
        return Colors.green.shade900;
      case 11:
        return Colors.deepPurpleAccent.shade100;
      default:
        return Colors.grey;
    }
  }

  // NEW MODEL FOR PDF DETAILS
}
