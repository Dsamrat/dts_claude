class ViewPayment {
  final String docNum;
  final String? pmtReceived;
  final String amountOption;
  final String paymentReceivedBy;
  final String amount;
  final String paymentMode;
  final String? chequeNumber;

  ViewPayment({
    required this.docNum,
    this.pmtReceived,
    required this.amountOption,
    required this.paymentReceivedBy,
    required this.amount,
    required this.paymentMode,
    this.chequeNumber,
  });

  factory ViewPayment.fromJson(Map<String, dynamic> json) {
    return ViewPayment(
      docNum: json['doc_num'] ?? '-',
      pmtReceived: json['pmt_received']?.toString(),
      amountOption: json['pmt_option'] ?? '-',
      paymentReceivedBy: json['pmt_received_by'] ?? '',
      amount: (double.tryParse(json['amount']?.toString() ?? '0') ?? 0)
          .toStringAsFixed(2),
      paymentMode: json['payment_mode'] ?? '-',
      chequeNumber: json['cheque_number'],
    );
  }
}
