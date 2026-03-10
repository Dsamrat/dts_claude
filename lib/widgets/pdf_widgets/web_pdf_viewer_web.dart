import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// import 'dart:ui' as ui_web;
import 'dart:ui_web' as ui_web; // ✅ Add this line

class WebPdfViewer extends StatelessWidget {
  final String pdfUrl;

  const WebPdfViewer({Key? key, required this.pdfUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Center(child: Text('Web PDF Viewer only works on Web.'));
    }

    // Use ValueKey based on PDF URL to force rebuild when URL changes
    final viewId = 'pdf-viewer-${pdfUrl.hashCode}';

    // Register the iframe (Web only)
    // ignore: undefined_prefixed_name

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int viewId) {
      final iframe =
          html.IFrameElement()
            ..src = pdfUrl
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%';
      return iframe;
    });

    return HtmlElementView(
      key: ValueKey(pdfUrl), // <-- ensures rebuild when URL changes
      viewType: viewId,
    );
  }
}
