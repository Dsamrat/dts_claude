import 'package:flutter/material.dart';
import 'package:dts/constants/common.dart';

class CustomDropdown<T> extends StatelessWidget {
  final String label;
  final List<T> items;
  final T? selectedItem;
  final void Function(T?) onChanged;
  final String Function(T) getLabel;

  const CustomDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.selectedItem,
    required this.onChanged,
    required this.getLabel,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: selectedItem,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: secondaryTeal, // 👈 Change this to your desired color
          fontSize: 16, // optional: adjust size
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorBorder, // Set your desired border color
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: colorBorder, // Set your desired border color
          ),
        ),
        // border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items:
          items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(getLabel(item)),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }
}
