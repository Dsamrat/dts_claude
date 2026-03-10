class PdfDetail {
  final int pdfId;
  final int invoiceId;
  final String docNum;
  final String resolvedDocNum;
  final String docType;
  final String? pdfLink; // Original PDF link
  final String? signedPdfLink; // Signed PDF link
  final String createdAt;
  final String updatedAt;

  PdfDetail({
    required this.pdfId,
    required this.invoiceId,
    required this.docNum,
    required this.resolvedDocNum,
    required this.docType,
    this.pdfLink,
    this.signedPdfLink,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PdfDetail.fromJson(Map<String, dynamic> json) {
    return PdfDetail(
      pdfId: json['pdf_id'] as int,
      invoiceId: json['invoice_id'] as int,
      docNum: json['doc_num'] as String,
      resolvedDocNum: json['resolved_doc_num'] as String,
      docType: json['doc_type'] as String,
      pdfLink: json['pdf_link'] as String?,
      signedPdfLink: json['signed_pdf_link'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }
}
