import 'package:flutter/material.dart';

class TabletLayoutWrapper extends StatelessWidget {
  final Widget child;
  const TabletLayoutWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 800, // Force tablet width
        ),
        child: child,
      ),
    );
  }
}
