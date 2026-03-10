import 'package:flutter/widgets.dart';

class WebPdfViewer extends StatelessWidget {
  final String pdfUrl;
  const WebPdfViewer({super.key, required this.pdfUrl});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Web PDF Viewer not supported on this platform.'),
    );
  }
}
