// lib/data_sources/user_data_source.dart
import 'package:flutter/material.dart';
import '../models/user.dart';

class UserDataSource extends DataTableSource {
  final List<User> users;
  final Function(User user) onEdit;
  final Function(int userId) onDelete;

  String searchQuery = '';
  final int _selectedCount = 0;

  UserDataSource({
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  void sort<T>(Comparable<T> Function(User u) getField, bool ascending) {
    users.sort((a, b) {
      final aVal = getField(a);
      final bVal = getField(b);
      return ascending
          ? Comparable.compare(aVal, bVal)
          : Comparable.compare(bVal, aVal);
    });
    notifyListeners();
  }

  void updateSearch(String query) {
    searchQuery = query.toLowerCase();
    notifyListeners();
  }

  List<User> get filteredUsers {
    final filtered =
        searchQuery.isEmpty
            ? users
            : users.where((u) {
              final name = u.name.toLowerCase();
              final username = u.userName.toLowerCase();
              final contact = u.contact.toLowerCase();
              return name.contains(searchQuery) ||
                  username.contains(searchQuery) ||
                  contact.contains(searchQuery);
            }).toList();
    return filtered;
  }

  @override
  DataRow? getRow(int index) {
    if (index >= filteredUsers.length) return null;
    final user = filteredUsers[index];
    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(Text(user.name)),
        // DataCell(Text(user.userName)),
        DataCell(Text(user.contact)),
        DataCell(
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => onEdit(user),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => onDelete(user.id!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => filteredUsers.length;

  @override
  int get selectedRowCount => _selectedCount;
}
