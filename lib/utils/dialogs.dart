import 'package:flutter/material.dart';

Future<void> showErrorDialog(
  BuildContext context,
  String message, {
  String title = 'Error', // <-- Default argument
}) {
  return showDialog(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
  );
}
