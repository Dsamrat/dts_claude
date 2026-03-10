// lib/widgets/subuser_data_table.dart
import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:dts/data_sources/user_data_source.dart';

class SubuserDataTable extends StatefulWidget {
  final List<User> users;
  final Function(User user) onEdit;
  final Function(int id) onDelete;

  const SubuserDataTable({
    super.key,
    required this.users,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SubuserDataTable> createState() => _SubuserDataTableState();
}

class _SubuserDataTableState extends State<SubuserDataTable> {
  late UserDataSource _dataSource;
  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dataSource = UserDataSource(
      users: widget.users,
      onEdit: widget.onEdit,
      onDelete: widget.onDelete,
    );
  }

  @override
  void didUpdateWidget(covariant SubuserDataTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.users != widget.users) {
      setState(() {
        _dataSource = UserDataSource(
          users: widget.users,
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        );
      });
    }
  }

  void _sort<T>(
    Comparable<T> Function(User u) getField,
    int columnIndex,
    bool ascending,
  ) {
    setState(() {
      _dataSource.sort(getField, ascending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _dataSource.updateSearch(value);
                });
              },
              decoration: InputDecoration(
                hintText: 'Search by name, username, contact...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: PaginatedDataTable(
                header: const Text('Sub-user List'),
                rowsPerPage: _rowsPerPage,
                onRowsPerPageChanged: (value) {
                  setState(() {
                    _rowsPerPage = value ?? _rowsPerPage;
                  });
                },
                sortColumnIndex: 0,
                sortAscending: true,
                columns: [
                  DataColumn(
                    label: const Text('Name'),
                    onSort: (i, asc) => _sort((u) => u.name, i, asc),
                  ),
                  DataColumn(
                    label: const Text('Contact'),
                    onSort: (i, asc) => _sort((u) => u.contact, i, asc),
                  ),
                  const DataColumn(label: Text('Actions')),
                ],
                source: _dataSource,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
