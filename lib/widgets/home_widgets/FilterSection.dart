import 'package:flutter/material.dart';
import 'package:dts/models/filter_option.dart';
import 'package:dts/models/branch.dart';
import 'package:dts/widgets/custom_dropdown.dart';
import 'package:dts/widgets/input.dart';

class FilterSection extends StatelessWidget {
  final bool showFilters;

  /// 📊 Centralized Data Source
  static const Map<String, Map<int, String>> _data = {
    'others': {
      0: 'Delivery in Progress',
      11: 'Awaiting Payment',
      1: 'Waiting for Delivery',
      2: 'Picking in Progress',
      3: 'Picked',
      4: 'Ready for Loading',
      5: 'Loaded',
      6: 'Dispatched',
      7: 'Delivery Completed',
      8: 'Canceled',
      9: 'Hold',
      10: 'Reschedule',
      999: 'Sign-Only',
    },
  };

  /// 🛠️ Static method so Parent can access the list without an instance
  static List<FilterOption> get allOptions =>
      _data['others']!.entries
          .map(
            (e) =>
                FilterOption(key: e.key.toString(), id: e.key, label: e.value),
          )
          .toList();

  // toggles
  final bool showStatusFilter;
  final bool showSearch;
  final bool showBranch;
  final bool showDate;

  // OPTIONAL status filter

  final FilterOption? selectedFilter;
  final Function(FilterOption?)? onFilterChanged;
  // branch
  final int? isMultiBranch;
  final List<Branch>? branchesDrop;
  final int? selectedBranchId;
  final Function(Branch?)? onBranchChanged;
  // search
  final TextEditingController? searchController;
  final VoidCallback? onSearch;
  final VoidCallback? onClearSearch;
  // date
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTimeRange?)? onDateRangeChanged;

  const FilterSection({
    super.key,
    required this.showFilters,
    this.showStatusFilter = false,
    this.showSearch = false,
    this.showBranch = false,
    this.showDate = false,

    // this.filterOptions,
    this.selectedFilter,
    this.onFilterChanged,

    this.isMultiBranch,
    this.branchesDrop,
    this.selectedBranchId,
    this.onBranchChanged,

    this.searchController,
    this.onSearch,
    this.onClearSearch,

    this.startDate,
    this.endDate,
    this.onDateRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!showFilters) return const SizedBox.shrink();
    // ✅ Use provided options or fall back to the internal list
    final options = FilterSection.allOptions;
    return Column(
      children: [
        const SizedBox(height: 10),
        /*if (showStatusFilter &&
            filterOptions != null &&
            filterOptions!.isNotEmpty &&
            onFilterChanged != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CustomDropdown<FilterOption>(
              label: "Filter by Status",
              items: filterOptions!,
              selectedItem: selectedFilter,
              onChanged: onFilterChanged!,
              getLabel: (o) => o.label,
            ),
          ),*/
        if (showStatusFilter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CustomDropdown<FilterOption>(
              label: "Filter by Status",
              items: options,
              selectedItem: selectedFilter,
              // Fix: Check if onFilterChanged is not null before calling it
              onChanged: (val) {
                if (onFilterChanged != null) {
                  onFilterChanged!(val);
                }
              },
              getLabel: (o) => o.label,
            ),
          ),
        // ✅ BRANCH
        if (showBranch &&
            isMultiBranch == 1 &&
            branchesDrop != null &&
            onBranchChanged != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: CustomDropdown<Branch>(
              label: "Select Branch",
              items: branchesDrop!,
              selectedItem: branchesDrop!.firstWhere(
                (b) => b.id == selectedBranchId,
                orElse: () => Branch(id: 0, name: 'Select'),
              ),
              onChanged: onBranchChanged!,
              getLabel: (b) => b.name,
            ),
          ),
        /*if (showSearch &&
            searchController != null &&
            onSearch != null &&
            onClearSearch != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            child: Input(
              placeholder:
                  'Search by invoice number, Order Id, Customer Name, Pdt SKU, Item Name...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: onSearch,
                  ),
                  if (searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: onClearSearch,
                    ),
                ],
              ),
              controller: searchController,
            ),
          ),*/
        if (showSearch &&
            searchController != null &&
            onSearch != null &&
            onClearSearch != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
            child: Input(
              placeholder:
                  'Search by invoice number, Order Id, Customer Name, Pdt SKU, Item Name...',
              controller: searchController,
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: searchController!,
                builder: (context, value, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: onSearch,
                      ),
                      if (value.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClearSearch,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        if (showDate && onDateRangeChanged != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.blueAccent),
                    const SizedBox(width: 12),

                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                            initialDateRange:
                                (startDate != null && endDate != null)
                                    ? DateTimeRange(
                                      start: startDate!,
                                      end: endDate!,
                                    )
                                    : null,
                          );

                          if (picked != null) {
                            onDateRangeChanged!(picked);
                          }
                        },
                        child: Text(
                          (startDate != null && endDate != null)
                              ? '${startDate!.toLocal().toString().split(' ')[0]} → ${endDate!.toLocal().toString().split(' ')[0]}'
                              : 'Select Date Range',
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                (startDate != null && endDate != null)
                                    ? Colors.black87
                                    : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    if (startDate != null && endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.redAccent),
                        onPressed: () => onDateRangeChanged!(null),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
