import 'package:flutter/material.dart';
import '../../models/branch.dart';

class BranchDropdown extends StatelessWidget {
  final List<Branch> branches;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const BranchDropdown({
    super.key,
    required this.branches,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: DropdownButton<int>(
        value: selectedId,
        isExpanded: true,
        dropdownColor: Colors.black87,
        style: const TextStyle(color: Colors.white),
        iconEnabledColor: Colors.white,
        hint: const Text(
          'Select Branch',
          style: TextStyle(color: Colors.white),
        ),
        items:
            branches.map((branch) {
              return DropdownMenuItem<int>(
                value: branch.id,
                child: Text(branch.name),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
