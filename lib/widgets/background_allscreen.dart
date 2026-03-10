import 'package:flutter/material.dart';

import '../constants/common.dart';

class backgroundAllScreen extends StatelessWidget {
  const backgroundAllScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [lightTeal1, lightTeal2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }
}
