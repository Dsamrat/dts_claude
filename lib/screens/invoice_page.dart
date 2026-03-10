import 'dart:io';
import 'package:dts/constants/common.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;

import '../widgets/pdf_widgets/web_pdf_viewer.dart'; // <-- only this
import '../utils/file_utils.dart';
import 'package:open_filex/open_filex.dart';

class InvoicePage extends StatefulWidget {
  // final Invoice invoice;
  final int? codFlag;
  final String? pdfLink;
  final String? docType;
  final String? resolvedDocNum;

  const InvoicePage({
    Key? key,
    // required this.invoice,
    this.codFlag,
    this.pdfLink,
    this.docType,
    this.resolvedDocNum,
  }) : super(key: key);

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  String? localPath;
  bool isLoading = true;
  bool isProcessing = false;
  String _iframeKey = DateTime.now().millisecondsSinceEpoch.toString();
  @override
  void initState() {
    super.initState();
    final urlToLoad = widget.pdfLink ?? '';
    debugPrint('$urlToLoad');
    if (urlToLoad.isEmpty) {
      setState(() {
        isLoading = false;
        localPath = null;
      });
      debugPrint('No valid PDF URL provided.');
      return;
    }

    if (!kIsWeb) {
      loadPDF(urlToLoad); // Mobile/Desktop
    } else {
      // On Web, WebPdfViewer handles iframe automatically
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> loadPDF(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File(
          '${dir.path}/temp_invoice_${DateTime.now().microsecondsSinceEpoch}.pdf',
        );
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          localPath = file.path;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          localPath = null;
        });
        debugPrint(
          'Failed to download PDF. Status code: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        localPath = null;
      });
      debugPrint('Error loading PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final docTitle = widget.resolvedDocNum ?? 'Invoice';
    final pdfLink = widget.pdfLink;

    return Scaffold(
      appBar: AppBar(
        title: Tooltip(
          message: docTitle,
          child: Text(docTitle, overflow: TextOverflow.ellipsis),
        ),
        backgroundColor: secondaryTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!kIsWeb && pdfLink != null && pdfLink.isNotEmpty)
            PopupMenuButton<String>(
              icon:
                  isProcessing
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.more_vert),
              onSelected: (value) async {
                final fileName = '${widget.resolvedDocNum}.pdf';
                final pdfType = widget.codFlag == 1 ? 'signed' : 'unsigned';

                setState(() => isProcessing = true);

                try {
                  if (value == 'share') {
                    FileUtils.showToast('Preparing to share $pdfType PDF...');
                    final path = await FileUtils.downloadPdf(
                      pdfLink,
                      fileName,
                      showToast: false,
                    );

                    if (path != null && await File(path).exists()) {
                      await FileUtils.sharePdf(path);
                      FileUtils.showToast('Shared successfully!');
                    } else {
                      FileUtils.showToast('PDF file not found to share');
                    }
                  } else if (value == 'download') {
                    final path = await FileUtils.downloadPdf(pdfLink, fileName);
                    if (path != null) await OpenFilex.open(path);
                  }
                } catch (e) {
                  FileUtils.showToast('Download failed: $e');
                } finally {
                  setState(() => isProcessing = false);
                }
              },
              itemBuilder:
                  (context) => [
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: const Icon(Icons.share),
                        title: Text('Share'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'download',
                      child: ListTile(
                        leading: const Icon(Icons.download),
                        title: Text('Download'),
                      ),
                    ),
                  ],
            ),
        ],
      ),

      body: Column(
        children: [
          if (isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (kIsWeb)
            Expanded(
              child: WebPdfViewer(pdfUrl: pdfLink!, key: ValueKey(_iframeKey)),
            )
          else if (localPath != null)
            Expanded(
              child: PDFView(
                filePath: localPath!,
                fitEachPage: true,
                fitPolicy: FitPolicy.BOTH,
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Failed to load PDF.'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                        });
                        if (kIsWeb) {
                          // Optionally, you could refresh the iframe URL here
                          setState(() {
                            _iframeKey =
                                DateTime.now().millisecondsSinceEpoch
                                    .toString();
                          });
                        } else {
                          loadPDF(pdfLink!);
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
