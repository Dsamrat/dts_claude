import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../services/driver_service.dart';
import '../widgets/drawer.dart';
import '../widgets/navbar.dart';
import '../widgets/pdf_widgets/web_pdf_viewer.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';

class SignatureScreen extends StatefulWidget {
  const SignatureScreen({super.key});
  @override
  State<SignatureScreen> createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final pdfLink =
      'https://5718011.app.netsuite.com/core/media/media.nl?id=5995037&c=5718011&h=HKnHeWkH4U3jAoUASmHKcdO62wG78gypw46cHd_nALnLd4BJ&_xt=.pdf';

  String? localPath;
  bool isLoading = true;
  bool _isSubmitting = false;

  int? currentUserId;
  int? currentDepartmentId;

  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  final DriverService _driverService = DriverService();

  @override
  void initState() {
    super.initState();

    loadPDF();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> loadPDF() async {
    try {
      final response = await http.get(Uri.parse(pdfLink));

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/temp_invoice.pdf');
        // print('File ${dir.path}');
        await file.writeAsBytes(response.bodyBytes, flush: true);

        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load PDF: ${response.statusCode}');
      }
    } catch (e) {
      // print("Error loading PDF: $e");
      setState(() {
        isLoading = false;
        localPath = null; // ensure no blank PDF
      });
    }
  }

  Future<void> _placeSignatureOnPdf(Uint8List signatureBytes) async {
    try {
      final file = File(localPath!);
      final PdfDocument document = PdfDocument(
        inputBytes: await file.readAsBytes(),
      );

      // Find "Receiver's Name"
      List<MatchedItem> matches = PdfTextExtractor(
        document,
      ).findText(['Receiver\'s Name']);

      if (matches.isEmpty) {
        // print("⚠️ 'Receiver's Name' not found in PDF");
        document.dispose();
        return;
      }

      final MatchedItem match = matches.first;
      final Rect textBounds = match.bounds;

      final PdfBitmap signatureImage = PdfBitmap(signatureBytes);

      document.pages[match.pageIndex].graphics.drawImage(
        signatureImage,

        Rect.fromLTWH(
          textBounds.right + 80, // 10px right of "Receiver's Name"
          textBounds.top - 5, // vertically align
          150, // width of signature
          50, // height of signature
        ),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final signedFile = File('${dir.path}/signed_invoice.pdf');
      await signedFile.writeAsBytes(bytes, flush: true);
      final Uint8List? image = await _controller.toPngBytes();
      if (image == null) {
        _showSnackBar('Failed to capture signature.');
        return;
      }
      // Convert signature image to base64
      final base64Signature = base64Encode(image);
      // Read file as bytes
      final Uint8List pdfBytes = await signedFile.readAsBytes();
      // Convert PDF to base64
      final String base64Pdf = base64Encode(pdfBytes);
      // Build payload
      final payloadData = {
        'signedDoc': base64Pdf, // PDF as base64 string
        'base64Signature': base64Signature, // Signature image as base64 string
      };

      // Call API
      final message = await _driverService.uploadTestSignature(
        payloadData: payloadData,
      );
      _showSnackBar(message);
      _controller.clear();
      // print("✅ Signed PDF saved at: ${signedFile.path}");
    } catch (e, st) {
      // print("❌ Error placing signature: $e\n$st");
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1), // Light teal background
      appBar: Navbar(title: "Dashboard"),
      drawer: ArgonDrawer(currentPage: "Home"),
      body: Padding(
        // padding: const EdgeInsets.all(8.0),
        padding: const EdgeInsets.only(top: 2.0),
        child: Column(
          children: [
            if (isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (kIsWeb)
              Expanded(child: WebPdfViewer(pdfUrl: pdfLink ?? ""))
            else if (localPath != null)
              Expanded(
                child: PDFView(
                  filePath: localPath!,
                  fitEachPage: true,
                  fitPolicy: FitPolicy.BOTH,
                ),
              ),

            Column(
              children: [
                // Signature Pad and Submit
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        "Customer Signature",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Signature(
                        controller: _controller,
                        height: 200,
                        backgroundColor: Colors.grey[200]!,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () => _controller.clear(),
                            child: const Text("Clear"),
                          ),
                          ElevatedButton(
                            onPressed:
                                _isSubmitting
                                    ? null
                                    : () async {
                                      if (_controller.isEmpty) {
                                        _showSnackBar(
                                          "Please provide a signature.",
                                        );
                                        return;
                                      }
                                      final Uint8List? signatureBytes =
                                          await _controller.toPngBytes();
                                      if (signatureBytes != null) {
                                        await _placeSignatureOnPdf(
                                          signatureBytes,
                                        );
                                      }
                                    },

                            child:
                                _isSubmitting
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text("Submit"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
