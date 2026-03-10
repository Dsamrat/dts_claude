import 'dart:io';
import 'package:dio/dio.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileUtils {
  /// Show a toast message
  static void showToast(
    String msg, {
    ToastGravity gravity = ToastGravity.BOTTOM,
  }) {
    Fluttertoast.showToast(msg: msg, gravity: gravity);
  }

  /// Download a PDF file from a URL and return the local path
  static Future<String?> downloadPdf(
    String url,
    String fileName, {
    bool showToast = true,
    Function(double percent)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory(); // <-- FIX
      final savePath = '${tempDir.path}/$fileName';

      final dio = Dio();

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final percent = (received / total * 100);
            onProgress(percent);
          }
        },
      );

      if (showToast) {
        FileUtils.showToast('PDF ready to share');
      }

      return savePath;
    } catch (e) {
      FileUtils.showToast('Download failed: $e');
      return null;
    }
  }

  /// Share a file (PDF or any file) using Share Plus

  static Future<void> sharePdfOld(String path, {String? text}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found at $path');
    }

    await Share.shareXFiles([XFile(path)], text: text ?? '');
  }

  static Future<void> sharePdf(String path, {String? text}) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found at $path');
    }

    await Share.shareXFiles([
      XFile(
        path,
        mimeType: 'application/pdf', // <-- FIX
      ),
    ], text: text ?? '');
  }
}
