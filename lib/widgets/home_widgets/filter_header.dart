import 'package:flutter/material.dart';

class FilterHeader extends StatelessWidget {
  final int totalResults;
  const FilterHeader({super.key, required this.totalResults});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🔹 Left: Total Results
          Row(
            children: [
              const Text(
                "Total Results: ",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
              Text(
                "$totalResults",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),

          // 🔹 Right: Filter Toggle
          /*IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt_off : Icons.filter_alt,
              color: Colors.teal,
            ),
            tooltip: showFilters ? "Hide Filters" : "Show Filters",
            onPressed: onToggle,
          ),*/
        ],
      ),
    );
  }
}
