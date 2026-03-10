class DeliveryRemarks {
  final int id;
  final String remarks;

  DeliveryRemarks({required this.id, required this.remarks});

  factory DeliveryRemarks.fromJson(Map<String, dynamic> json) {
    return DeliveryRemarks(id: json['id'], remarks: json['remarks']);
  }
}
