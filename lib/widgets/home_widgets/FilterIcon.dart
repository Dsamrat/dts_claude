import 'package:flutter/material.dart';

import '../../constants/common.dart';

class FilterIcon extends StatelessWidget {
  final bool showFilters;
  final VoidCallback onToggle;

  const FilterIcon({
    super.key,
    required this.showFilters,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              "Toggle Filter",
              style: TextStyle(
                color: secondaryTeal,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt_off : Icons.filter_alt,
              color: secondaryTeal,
            ),
            onPressed: onToggle,
            tooltip: showFilters ? "Hide Filters" : "Show Filters",
          ),
        ],
      ),
    );
  }
}
