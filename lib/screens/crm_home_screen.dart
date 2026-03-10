import 'dart:convert';
import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/common.dart';

import '../models/branch.dart';
import '../models/filter_option.dart';
import '../services/branch_service.dart';
import '../services/crm_service.dart';
import '../services/invoice_service.dart';
import '../services/pusher_service.dart';
import '../widgets/action_modal_form.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/build_flag.dart';
import '../widgets/common_pdf_icon.dart';
import '../widgets/drawer.dart';
import '../widgets/hold_cancel_info.dart';
import '../widgets/home_widgets/FilterSection.dart';
import '../widgets/home_widgets/filter_header.dart';
import '../widgets/invoice_item/common_invoice_item.dart';
import '../widgets/invoice_item/invoice_item_config.dart';
import '../widgets/invoice_item/invoice_screen_type.dart';
import '../widgets/navbar.dart';
import '../widgets/pdf_widgets/delivery_type_icon.dart';
import 'crm_invoice_timeline.dart';
import 'invoice_page.dart';

import '../utils/pusher_connector_interface.dart' as connector_interface;
import '../utils/pusher_connector_stub_impl.dart'
    if (dart.library.js) '../utils/pusher_connector_web_impl.dart'
    if (dart.library.io) '../utils/pusher_connector_stub_impl.dart'
    as connector_impl;

class UpdateSummary {
  final int insertedCount;
  final int updatedCount;
  UpdateSummary(this.insertedCount, this.updatedCount);
}

class CrmHomeScreen extends StatefulWidget {
  final int? initialFilterOption;
  final int? initialBranchId;
  final String? initialStart;
  final String? initialEnd;
  final String? initialPage;

  const CrmHomeScreen({
    super.key,
    this.initialFilterOption,
    this.initialBranchId,
    this.initialStart,
    this.initialEnd,
    this.initialPage,
  });

  @override
  State<CrmHomeScreen> createState() => _CrmHomeScreenState();
}

class _CrmHomeScreenState extends State<CrmHomeScreen> {
  /* User & Filters */
  int? currentUserId;
  int? currentUserBranchId;
  int? userDepartmentId;
  /*pagination*/
  int? isMultiBranch;
  int currentPage = 1;
  bool isLoading = false; // initial & refresh loading
  bool _isLoadingMore = false; // pagination spinner
  bool _hasNextPage = true;

  List<Map<String, dynamic>> invoices = [];
  final ScrollController _scrollController = ScrollController();
  int? totalResults;
  int? selectedBranchId;
  DateTime? startDate;
  DateTime? endDate;
  List<Branch> branchesDrop = [];
  /*pagination*/

  /* Data */
  bool showFilters = false;
  /* Services */
  final BranchService _branchService = BranchService();
  final CrmService _crmService = CrmService();
  final InvoiceService _invoiceService = InvoiceService();
  final TextEditingController _searchController = TextEditingController();
  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;
  bool _expanded = false;
  int? expandedIndex;

  Map<int, bool> signUpdating = {};
  FilterOption? selectedFilter;

  @override
  void initState() {
    super.initState();
    /*pagination*/
    _scrollController.addListener(_onScroll);
    /*pagination*/
    _pusherConnector = connector_impl.createPusherConnector();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserDetails();
    if (kIsWeb && !_pusherInitialized) {
      _initializePusherWeb();
      _pusherInitialized = true;
    } else if (!kIsWeb) {
      await _initPusher();
    }
  }

  /*pagination*/
  void _onScroll() {
    if (_hasNextPage && !_isLoadingMore) {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent) {
        _loadMoreInvoices();
      }
    }
  }

  Future<void> _loadMoreInvoices() async {
    debugPrint('_hasNextPage: $_hasNextPage');
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    currentPage++;
    debugPrint(currentPage.toString());
    await fetchCrmInvoices(); /*page: currentPage*/
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  /*pagination*/

  void _initializePusherWeb() {
    final channelNameWeb = 'crm-$currentUserBranchId';
    const String eventNameWeb = 'crm.created'; // Example dynamic value

    _pusherConnector.initPusherWeb(
      channelNameWeb, // Pass the channel prefix
      eventNameWeb, // Pass the event name
      _handlePusherEventWeb,
    );
  }

  void _openMap(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) return;

    final Uri googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handlePusherEventWeb(dynamic raw) async {
    try {
      if (raw == null || raw.toString().isEmpty) return;
      final decoded = jsonDecode(
        raw.toString(),
      ); // 👈 convert JSON string to Dart object
      if (decoded is! Map<String, dynamic>) {
        debugPrint('❌ Unexpected Pusher payload format: $decoded');
        return;
      }

      await onPusherEventReceivedWeb(decoded);
    } catch (e, st) {
      debugPrint("❌ Error in _handlePusherEventWeb: $e");
      debugPrint("$st");
    }
  }

  Future<void> onPusherEventReceivedWeb(
    Map<String, dynamic> eventPayload,
  ) async {
    final UpdateSummary updateSummary = await _handleNewInvoiceFromPusher(
      eventPayload,
    );

    if (!mounted) return;

    if (updateSummary.insertedCount > 0 || updateSummary.updatedCount > 0) {
      final int totalChanges =
          updateSummary.insertedCount + updateSummary.updatedCount;
      String message;

      // Determine the specific message based on counts
      if (updateSummary.insertedCount > 0 && updateSummary.updatedCount > 0) {
        message =
            '$totalChanges Invoices: ${updateSummary.insertedCount} inserted, ${updateSummary.updatedCount} updated.';
      } else if (updateSummary.insertedCount > 0) {
        message =
            '${updateSummary.insertedCount} New Invoice${updateSummary.insertedCount > 1 ? 's' : ''} Inserted';
      } else {
        message =
            '${updateSummary.updatedCount} Invoice${updateSummary.updatedCount > 1 ? 's' : ''} Updated';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }

    // ✅ Ensure UI refresh happens inside the function
    setState(() {});
  }

  Future<UpdateSummary> _handleNewInvoiceFromPusher(
    Map<String, dynamic> eventData,
  ) async {
    final raw = eventData['invoiceID'];
    final List<int> invoiceIds = [];

    if (raw is List) {
      invoiceIds.addAll(
        raw.map((e) => int.tryParse(e.toString())).whereType<int>(),
      );
    } else if (raw is Map) {
      invoiceIds.addAll(
        raw.values.map((e) => int.tryParse(e.toString())).whereType<int>(),
      );
    } else if (raw != null) {
      final id = int.tryParse(raw.toString());
      if (id != null) invoiceIds.add(id);
    }

    if (invoiceIds.isEmpty) return UpdateSummary(0, 0);

    debugPrint('📦 Invoice IDs from Pusher: $invoiceIds');

    final result = await _crmService.fetchInvoicesForSalesman(
      page: 1,
      invoiceIds: invoiceIds,
      filter: selectedFilter?.id.toString() ?? '0',
      userBranchId: selectedBranchId,
      search: _searchController.text,
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
    );

    int inserted = 0;
    int updated = 0;

    if (result["status"] == "success") {
      // ✅ Always read from result['invoices']['data']
      final List<dynamic> fetchedInvoices = List<dynamic>.from(
        result['invoices']['data'] ?? [],
      );

      for (final newInvoice in fetchedInvoices) {
        final idx = invoices.indexWhere(
          (i) => i['invoice_id'] == newInvoice['invoice_id'],
        );
        if (idx == -1) {
          invoices.insert(0, newInvoice);
          inserted++;
        } else {
          invoices[idx] = newInvoice;
          updated++;
        }
      }
    }

    // 🧹 Remove missing invoices
    if (result["status"] == "missing") {
      final missingIds = result["missing"] as List<dynamic>? ?? [];
      invoices.removeWhere((i) => missingIds.contains(i['invoice_id']));
    }

    if (mounted) setState(() {});

    return UpdateSummary(inserted, updated);
  }

  Future<void> _initPusher() async {
    final pusherService = PusherService(
      apiKey: pusherAPIKey,
      cluster: pusherCluster,
      authEndpoint: pusherAuthURl,
      userToken: '',
    );
    final channelName = 'crm-$currentUserBranchId';

    pusherService.on(channelName, 'crm.created', (data) async {
      debugPrint(
        "📡 Event received on channel '$channelName': crm.created, Data: $data",
      );

      final Map<String, dynamic> eventPayload =
          jsonDecode(data.toString()) as Map<String, dynamic>;

      await onPusherEventReceivedWeb(eventPayload);
    });

    await pusherService.init();
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isMultiBranch = prefs.getInt('multiBranch');
      currentUserBranchId = prefs.getInt('branchId');
      currentUserId = prefs.getInt('userId');
      userDepartmentId = prefs.getInt('departmentId');

      selectedBranchId =
          (widget.initialPage == 'Home')
              ? widget.initialBranchId
              : currentUserBranchId;
    });

    // 1. Get the list directly from the Class definition
    final availableOptions = FilterSection.allOptions;

    // 2. Handle the initial selection logic
    if (widget.initialFilterOption != null) {
      // Find the object in the static list that matches the ID passed to the page
      selectedFilter = availableOptions.firstWhere(
        (f) => f.id == widget.initialFilterOption,
        orElse: () => availableOptions.first,
      );
      showFilters = true;
    } else {
      selectedFilter = availableOptions.first;
    }
    if (isMultiBranch == 1) {
      branchesDrop = await _branchService.getBranches();
    }
    if (widget.initialStart != null) {
      startDate = DateTime.parse(widget.initialStart!);
    }
    if (widget.initialEnd != null) {
      endDate = DateTime.parse(widget.initialEnd!);
    }

    if (currentUserId != null) {
      fetchCrmInvoices();
    }
  }

  Future<void> fetchCrmInvoices({
    List<int>? invoiceIds,
    bool reset = false,
  }) async {
    // if (selectedBranchId == null) return;
    if (isLoading) return;

    if (reset) {
      currentPage = 1;
      invoices.clear();
      _hasNextPage = true;
    }

    if (!_hasNextPage) return;

    setState(() => isLoading = true);

    try {
      final res = await _crmService.fetchInvoicesForSalesman(
        page: currentPage,
        userBranchId: selectedBranchId,
        search: _searchController.text,
        filter: selectedFilter?.id.toString() ?? '0',
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );
      debugPrint(res.toString());
      if (!mounted) return;

      /*final container = res['invoices'];
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(
        container['data'],
      );

      setState(() {
        for (final invoice in data) {
          if (!invoices.any((i) => i['invoice_id'] == invoice['invoice_id'])) {
            invoices.add(invoice);
          }
        }
        totalResults = container['total'];
        _hasNextPage = currentPage < container['last_page'];
        isLoading = false;
      });*/
      // ---------------- SAFE PARSING ----------------
      List<Map<String, dynamic>> data = [];
      int lastPage = 1;
      int total = 0;

      if (res['status'] == 'success') {
        // ✅ NORMAL PAGINATED RESPONSE
        if (res['invoices'] != null) {
          final container = res['invoices'];

          data = List<Map<String, dynamic>>.from(container['data'] ?? []);

          lastPage = container['last_page'] ?? 1;
          total = container['total'] ?? data.length;
        }
        // ✅ EMPTY RESPONSE SHAPE
        else if (res['data'] != null) {
          data = List<Map<String, dynamic>>.from(res['data']);

          final meta = res['meta'] ?? {};
          lastPage = meta['last_page'] ?? 1;
          total = data.length;
        }
      } else {
        throw Exception(res['message'] ?? 'API error');
      }
      // ---------------- UPDATE STATE ----------------
      setState(() {
        for (final invoice in data) {
          if (!invoices.any((i) => i['invoice_id'] == invoice['invoice_id'])) {
            invoices.add(invoice);
          }
        }

        totalResults = total;
        _hasNextPage = currentPage < lastPage;
        isLoading = false;
      });
    } catch (e, stack) {
      if (!mounted) return;
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Failed to load invoices')),
      );
    }
  }

  /// 🔹 Convert hex color string like "#FF0000" → Color

  IconData _getStatusIcon(int? invoiceStatus) {
    switch (invoiceStatus) {
      case 8:
        return Icons.cancel; // Cancel
      case 9:
        return Icons.lock; // Hold
      case 10:
        return Icons.history; // Reschedule
      default:
        return Icons.no_encryption; // Default
    }
  }

  IconData _getDeliveryTypeIcon(String? deliveryType) {
    switch (deliveryType) {
      case 'Customer Collection':
        return Icons.directions_walk;
      case 'Courier':
        return Icons.local_shipping; // Hold

      default:
        return Icons.fire_truck; // Default
    }
  }

  static String mapStatus(int status) {
    switch (status) {
      case 1:
        return 'Waiting for Delivery';
      case 2:
        return 'Picking in Progress';
      case 3:
        return 'Picked';
      case 4:
        return 'Ready for Loading';
      case 5:
        return 'Loaded';
      case 6:
        return 'Dispatched';
      case 7:
        return 'Delivery Completed';
      case 8:
        return 'Canceled';
      case 11:
        return 'Awaiting Payment';
      default:
        return 'Unknown';
    }
  }

  String getInitialAction({
    required int invoiceCurrentStatus,
    required int holdStatus,
  }) {
    if (invoiceCurrentStatus == 8) {
      return "Cancel";
    } else if (holdStatus == 9) {
      return "Hold";
    } else if (holdStatus == 10) {
      return "Reschedule";
    }
    return ""; // default if no status
  }

  IconData _getSignIcon(int? signOnly) {
    return signOnly == 1 ? Icons.aod_outlined : Icons.app_blocking_outlined;
  }

  Color _getSignColor(int? signOnly) {
    return signOnly == 1 ? Colors.red : Colors.grey;
  }

  String getConfirmMessage(int? signOnly) {
    return signOnly == 1
        ? 'Confirm to remove sign-only?'
        : 'Confirm to mark as sign-only?';
  }

  Future<bool> showConfirmDialog(BuildContext context, String message) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Confirmation'),
                content: Text(message),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _toggleSignOnly(Map<String, dynamic> invoice, int index) async {
    final int invoiceId = int.tryParse(invoice['invoice_id'].toString()) ?? 0;
    final int currentValue = invoice['sign_only'] ?? 0;
    final int newValue = currentValue == 1 ? 0 : 1;

    final int currentStatus = invoice['invoice_status_int'] ?? 0;
    // 🔒 Save original values (for rollback)
    final int originalSignOnly = currentValue;
    final int originalStatus = currentStatus;

    // 🔥 Start loader before API
    setState(() {
      signUpdating[invoiceId] = true;
    });
    // ⚡ Optimistic UI update
    setState(() {
      invoices[index]['sign_only'] = newValue;
      // Case 1: signOnly=1 and status=5 or 6 → status becomes 1
      if (currentValue == 1 && (currentStatus == 5 || currentStatus == 6)) {
        invoices[index]['invoice_status_int'] = 1;
        invoices[index]['invoice_status'] = 'Waiting for Delivery';
      }
      // Case 2: signOnly=0 and status=1 → status becomes 5
      else if (currentValue == 0 && currentStatus == 1) {
        invoices[index]['invoice_status_int'] = 5;
        invoices[index]['invoice_status'] = 'Loaded';
      }
    });

    bool success = false;

    try {
      success = await _crmService.toggleSignOnly(
        newValue,
        currentUserId!,
        invoiceId,
      );
      // ❌ API failed → rollback
      if (!success) {
        setState(() {
          invoices[index]['sign_only'] = originalSignOnly;
          invoices[index]['invoice_status_int'] = originalStatus;
          invoices[index]['invoice_status'] = mapStatus(originalStatus);
        });
      }
    } catch (e) {
      success = false;
      setState(() {
        invoices[index]['sign_only'] = originalSignOnly;
        invoices[index]['invoice_status_int'] = originalStatus;
        invoices[index]['invoice_status'] = mapStatus(originalStatus);
      });
    }

    // 🔥 Stop loader
    setState(() {
      signUpdating.remove(invoiceId);
    });
    debugPrint("Loader stop → $signUpdating");

    // 🌟 Show appropriate snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? (newValue == 1 ? 'Sign Only Enabled' : 'Sign Only Disabled')
              : 'Failed to update sign only status',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  void _openStatusPopup(Map<String, dynamic> invoice, int index) {
    String initialAction = getInitialAction(
      invoiceCurrentStatus: invoice['invoice_status_int'],
      holdStatus: invoice['holdStatus'],
    );

    showDialog(
      context: context,
      builder:
          (_) => ActionModalForm(
            initialActionType: initialAction,
            initialReason: invoice['holdReason'],
            initialDateTime:
                invoice['holdReschedule'] != null
                    ? DateTime.tryParse(invoice['holdReschedule'])
                    : null,
            invoiceCurrentStatus: invoice['invoice_status_int'],
            expressFlag: invoice['expressFlag'],
            onSubmit: (action, reason, dateTime, confirmed) async {
              // Call API here
              try {
                bool success = false;

                success = await _invoiceService.toggleInvoiceStatus(
                  action,
                  reason,
                  dateTime,
                  confirmed ? 1 : 0,
                  currentUserId!.toInt(),
                  currentUserBranchId!.toInt(),
                  invoice['invoice_id'],
                );

                if (success) {
                  // Update UI
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Status updated')));
                  // Update invoice status in state
                  setState(() {
                    if (action == "Cancel") {
                      invoices[index]['invoice_status_int'] = 8;
                      invoices[index]['invoice_status'] = 'Canceled';
                      invoices[index]['holdStatus'] = 0;
                      invoices[index]['holdReason'] = reason.toString();
                    } else if (action == "Hold") {
                      invoices[index]['holdStatus'] = 9;
                      invoices[index]['holdReason'] = reason.toString();
                    } else if (action == "Reschedule") {
                      invoices[index]['holdStatus'] = 10;
                      invoices[index]['holdReason'] = reason.toString();
                    } else if (action == "Unhold") {
                      invoices[index]['holdStatus'] = 0;
                      invoices[index]['holdReason'] = null;
                    }
                  });
                  if (action == "Cancel") {
                    invoices.removeWhere(
                      (e) => e['invoice_id'] == invoice['invoice_id'],
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update status')),
                  );
                }
              } catch (e) {
                debugPrint('Error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating status')),
                );
              }
            },
          ),
    );
  }

  void _openDeliveryTypePopup(
    String? currentType,
    int? invoiceId,
    int index,
  ) async {
    // Always start fresh
    final initialSelection = currentType ?? 'Regular';

    // Build allowed options without mutating old lists
    List<String> filteredOptions = switch (currentType) {
      null => ['Customer Collection', 'Courier'],
      'Customer Collection' => ['Courier', 'Regular'],
      'Courier' => ['Customer Collection', 'Regular'],
      _ => ['Courier', 'Customer Collection', 'Regular'],
    };

    // Add current selection and remove duplicates
    filteredOptions = [...filteredOptions, initialSelection];
    // Deduplicate while preserving order
    final seen = <String>{};
    filteredOptions = [
      for (final opt in filteredOptions)
        if (seen.add(opt)) opt,
    ];

    debugPrint('Before dialog: $filteredOptions'); // 🔎 Debug

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempSelection = initialSelection;
        return AlertDialog(
          title: const Text('Select Delivery Type'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    filteredOptions.map((opt) {
                      return RadioListTile<String>(
                        title: Text(opt),
                        value: opt,
                        groupValue: tempSelection,
                        onChanged:
                            (val) => setState(() => tempSelection = val!),
                      );
                    }).toList(),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, tempSelection),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != currentType) {
      final success = await _invoiceService.toggleDeliveryType(
        selected,
        currentUserId!,
        invoiceId!,
      );
      if (success) {
        setState(() {
          invoices[index]['delivery_type'] = selected;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Status updated')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  @override
  void dispose() {
    /*pagination*/
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    /*pagination*/
    super.dispose();
  }

  Widget _allInvoicesList() {
    // Show full screen loader ONLY on first load/reset
    if (isLoading && invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => fetchCrmInvoices(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                FilterHeader(totalResults: totalResults ?? 0),
                FilterSection(
                  showFilters: showFilters,
                  showStatusFilter: true,
                  showSearch: true,
                  showBranch: true,
                  showDate: true,
                  selectedFilter: selectedFilter,
                  onFilterChanged: (option) {
                    setState(() {
                      selectedFilter = option;
                      currentPage = 1;
                      invoices.clear();
                    });
                    fetchCrmInvoices(reset: true);
                  },
                  isMultiBranch: isMultiBranch,
                  branchesDrop: branchesDrop,
                  selectedBranchId: selectedBranchId,
                  onBranchChanged: (branch) {
                    setState(() {
                      selectedBranchId = branch?.id;
                      currentPage = 1;
                      invoices.clear();
                    });
                    fetchCrmInvoices(reset: true);
                  },
                  searchController: _searchController,
                  onSearch: () {
                    currentPage = 1;
                    invoices.clear();
                    fetchCrmInvoices(reset: true);
                  },
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                    currentPage = 1;
                    invoices.clear();
                    fetchCrmInvoices(reset: true);
                  },
                  startDate: startDate,
                  endDate: endDate,
                  onDateRangeChanged: (range) {
                    setState(() {
                      startDate = range?.start;
                      endDate = range?.end;
                      currentPage = 1;
                      invoices.clear();
                    });
                    fetchCrmInvoices(reset: true);
                  },
                ),
              ],
            ),
          ),

          // If no records found after loading
          if (!isLoading && invoices.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text("No records found")),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Check if we are at the end of the current list
                  if (index == invoices.length) {
                    return _hasNextPage
                        ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : const SizedBox.shrink(); // No more data
                  }

                  return _buildInvoiceItem(invoices[index], index);
                },
                // Add 1 to the count to show the loader at the bottom
                childCount: invoices.length + (_hasNextPage ? 1 : 0),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: const Navbar(title: "Deliveries"),
      appBar: Navbar(
        title: "Deliveries",
        rightOptions: true,
        showFilter: true,
        filterEnabled: showFilters,
        onFilterPressed: () {
          setState(() => showFilters = !showFilters);
        },
      ),
      drawer: const ArgonDrawer(currentPage: "Deliveries"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          // The list handles its own loading states internally now
          Column(children: [Expanded(child: _allInvoicesList())]),
        ],
      ),
    );
  }

  // --- Solution for the _buildPdfIcons error ---
  Widget _buildPdfIcons(
    BuildContext context,
    Map<String, dynamic> invoice,
    int startKm, // Changed to int since it's parsed to int
    isDisabled,
  ) {
    List<Widget> pdfWidgets = [];

    final List<dynamic> pdfsData = (invoice['pdfs'] as List<dynamic>?) ?? [];

    if (pdfsData.isNotEmpty) {
      for (var pdfJson in pdfsData) {
        final String? docType = pdfJson['doc_type'] as String?;
        final String? pdfLink = pdfJson['pdf_link'] as String?;
        final String? signedPdfLink = pdfJson['signed_pdf_link'] as String?;
        final String? linkToOpen =
            signedPdfLink?.isNotEmpty == true ? signedPdfLink : pdfLink;

        if (linkToOpen?.isNotEmpty == true) {
          pdfWidgets.add(
            IgnorePointer(
              ignoring: isDisabled,
              child: InkWell(
                onTap: () {
                  final resolvedDocNum = pdfJson['resolved_doc_num'];
                  final String resolved =
                      resolvedDocNum?.toString().trim() ?? "";

                  // Navigate only if valid
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => InvoicePage(
                            codFlag: int.tryParse(
                              invoice['cod_flag'].toString(),
                            ),
                            pdfLink: linkToOpen,
                            docType: docType ?? '',
                            resolvedDocNum: resolved,
                          ),
                    ),
                  );
                },

                child: Tooltip(
                  message:
                      pdfJson['signed_pdf_link'] != null &&
                              pdfJson['signed_pdf_link']!.isNotEmpty
                          ? 'Signed ' + (pdfJson['doc_type'] ?? '')
                          : 'Unsigned ' + (pdfJson['doc_type'] ?? ''),
                  child: Icon(
                    pdfJson['doc_type'] == 'Invoice'
                        ? Icons.request_quote
                        : Icons.description,
                    color:
                        isDisabled
                            ? Colors
                                .grey // visually show disabled
                            : pdfJson['signed_pdf_link'] != null &&
                                pdfJson['signed_pdf_link']!.isNotEmpty
                            ? Colors.blue
                            : Colors.red,
                    size: 28,
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Row(
      mainAxisSize:
          MainAxisSize.min, // Ensure it doesn't take full width unnecessarily
      children:
          pdfWidgets.isNotEmpty
              ? pdfWidgets
              : [
                const Text(
                  'No PDFs', // More compact placeholder
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
    );
  }
  // lib/screens/crm_home_screen.dart

  /* Widget _buildInvoiceItem(Map<String, dynamic> invoice, int index) {
    return CommonInvoiceItem(
      invoice: invoice,
      config: InvoiceItemConfig(
        screenType: InvoiceScreenType.crm,
        index: index,
        expandedIndex: expandedIndex,
        onExpansionChanged: (idx) {
          setState(() {
            expandedIndex = expandedIndex == idx ? null : idx;
          });
        },
        onOpenMap: _openMap,
        signUpdating: signUpdating,
        onOpenStatusPopup: _openStatusPopup,
        // onOpenDeliveryTypePopup: _openDeliveryTypePopup,
        onOpenDeliveryTypePopup: (type, invoiceId, index) {
          _openDeliveryTypePopup(type, invoiceId as int?, index);
        },
        onToggleSignOnly: (inv, idx) async {
          final confirm = await showConfirmDialog(
            context,
            getConfirmMessage(inv['sign_only']),
          );
          if (confirm) {
            _toggleSignOnly(inv, idx);
          }
        },
        onOpenTimeline: (inv, idx) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CRMInvoiceTimeLine(invoice: inv, index: idx),
            ),
          );
        },
      ),
    );
  }*/

  Widget _buildInvoiceItem(Map<String, dynamic> invoice, int index) {
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ?? [];
    /*final isDisabled = isInvoiceDisabled(
      invoice['invoice_status_int'],
      invoice['holdStatus'],
    );*/
    final isDisabled = false;
    final int invoiceId = int.tryParse(invoice['invoice_id'].toString()) ?? 0;
    // print("Checking loader for $invoiceId => ${signUpdating[invoiceId]}");
    final iconData = _getStatusIcon(invoice['invoice_status_int']);
    final deliveryTypeIconData = _getDeliveryTypeIcon(invoice['delivery_type']);
    final bool isVisible =
        invoice['invoice_status_int'] != null &&
        ((invoice['sign_only'] == 1 &&
                (invoice['invoice_status_int'] == 5 ||
                    invoice['invoice_status_int'] == 6)) ||
            (invoice['sign_only'] == 0 && invoice['invoice_status_int'] == 1));

    // 2. This controls if the button is INTERACTIVE (Disabled if on hold)
    final bool isHold = invoice['holdStatus'] == 9;
    final bool canToggle = !(invoice['sign_only'] == 0 && isHold);
    final bool isDeliveryCompleted =
        invoice['invoice_status_int'] == 7 &&
        invoice['delivery_remarks'] != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: getInvoiceCardBGColor(
          invoiceCurrentStatus: invoice['invoice_status_int'],
          holdStatus: invoice['holdStatus'],
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // ---------- HEADER SECTION ----------
          GestureDetector(
            onTap: () {
              setState(() {
                expandedIndex = expandedIndex == index ? null : index;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// TITLE + STATUS + ARROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        invoice['doc_num'] ?? 'Invoice',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                      ),

                      Row(
                        children: [
                          buildFlag(
                            (invoice['invoice_status'] ?? 'Unknown').replaceAll(
                              '\\n',
                              '\n',
                            ),
                            getStatusColor(invoice['invoice_status_int']),
                          ),

                          const SizedBox(width: 6),

                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 28,
                            color: Colors.black54,
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // → You can keep all your other header details here unchanged
                  if (invoice['other_branch_del'] == 1)
                    (invoice['del_from_branch_name'] != null &&
                            invoice['del_from_branch_name']!.isNotEmpty)
                        ? RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                            children: [
                              const TextSpan(text: 'Delivery From '), // regular
                              TextSpan(
                                text:
                                    (invoice['del_from_branch_name'] as String?)
                                        ?.capitalize(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ), // bold
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                        : const SizedBox.shrink(),
                  const SizedBox(height: 4), // Add some spacing if needed
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (invoice['customer_name']?.isNotEmpty == true)
                        Expanded(
                          child: Text(
                            (invoice['customer_name'] as String?)
                                    ?.toTitleCase() ??
                                '',
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (invoice['customer_latitude'] != null &&
                      invoice['customer_longitude'] != null)
                    GestureDetector(
                      onTap: () {
                        final latString = invoice['customer_latitude'];
                        final lngString = invoice['customer_longitude'];
                        final lat =
                            (latString is String)
                                ? double.tryParse(latString)
                                : latString?.toDouble();
                        final lng =
                            (lngString is String)
                                ? double.tryParse(lngString)
                                : lngString?.toDouble();

                        if (lat != null && lng != null) {
                          _openMap(lat, lng);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Location not available"),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 6),
                          // Build text only if there’s something to show
                          if ((invoice['cus_distance'] != null &&
                                  invoice['cus_distance']
                                      .toString()
                                      .isNotEmpty &&
                                  invoice['cus_distance']
                                          .toString()
                                          .toLowerCase() !=
                                      'unknown') ||
                              (invoice['subLocality'] != null &&
                                  invoice['subLocality'].toString().isNotEmpty))
                            Text(
                              [
                                // if distance exists and not 'unknown'
                                if (invoice['cus_distance'] != null &&
                                    invoice['cus_distance']
                                        .toString()
                                        .isNotEmpty &&
                                    invoice['cus_distance']
                                            .toString()
                                            .toLowerCase() !=
                                        'unknown')
                                  invoice['cus_distance'].toString(),
                                // if subLocality'] exists
                                if (invoice['subLocality'] != null &&
                                    invoice['subLocality']
                                        .toString()
                                        .isNotEmpty)
                                  invoice['subLocality'].toString(),
                              ].join(' • '), // combines them nicely
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            )
                          else
                            const Text(
                              "No location info",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sales Person & Created By Row 👇
                      if ((invoice['displaySalesRep'] != null &&
                              invoice['displaySalesRep']
                                  .toString()
                                  .trim()
                                  .isNotEmpty) ||
                          (invoice['displayCreatedBy'] != null &&
                              invoice['displayCreatedBy']
                                  .toString()
                                  .trim()
                                  .isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Row(
                            children: [
                              if (invoice['displaySalesRep'] != null &&
                                  invoice['displaySalesRep']
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.teal,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'Sales: ${invoice['displaySalesRep']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],

                              if (invoice['displaySalesRep'] != null &&
                                  invoice['displaySalesRep']
                                      .toString()
                                      .trim()
                                      .isNotEmpty &&
                                  invoice['displayCreatedBy'] != null &&
                                  invoice['displayCreatedBy']
                                      .toString()
                                      .trim()
                                      .isNotEmpty)
                                const SizedBox(width: 8),

                              if (invoice['displayCreatedBy'] != null &&
                                  invoice['displayCreatedBy']
                                      .toString()
                                      .trim()
                                      .isNotEmpty) ...[
                                const Icon(
                                  Icons.badge,
                                  size: 14,
                                  color: Colors.black87,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'By: ${invoice['displayCreatedBy']}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                  if (invoice['order_id'] != null &&
                      invoice['order_id'].isNotEmpty)
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Order ID: ',
                            style: TextStyle(
                              // fontWeight: FontWeight.bold,
                              color: secondaryTeal,
                            ),
                          ),
                          TextSpan(
                            text: '${invoice['order_id']}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      // Created At
                      const Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: secondaryTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        invoice['doc_created_at'],
                        style: const TextStyle(
                          fontSize: 14,
                          // fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                      ),
                      const SizedBox(width: 2), // space between the two dates
                      // Expected Delivery Time
                      if (invoice['expectedDeliveryTime'] != null &&
                          invoice['expectedDeliveryTime'].isNotEmpty) ...[
                        expectedDelivery(size: 18),
                        const SizedBox(width: 4),
                        Text(
                          invoice['expectedDeliveryTime'],
                          style: const TextStyle(
                            fontSize: 14,
                            // fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                          ),
                        ),
                      ],
                    ],
                  ),

                  if (invoice['del_remarks'] != null &&
                      invoice['del_remarks'].isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.message,
                          size: 18,
                          color: secondaryTeal,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            invoice['del_remarks'] ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: secondaryTeal,
                            ),
                            maxLines: null,
                            softWrap: true,
                          ),
                        ),
                      ],
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4.0,
                          runSpacing: 4.0,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (invoice['hard_copy'] == 1)
                              buildFlag('H', Colors.orange),
                            // Space between flags horizontally
                            if (invoice['cod_flag'] == 1)
                              buildFlag('COD', Colors.green),

                            if (invoice['sign_only'] == 1)
                              buildFlag('Sign Only', Colors.red),
                            if (invoice['expressFlag']?.toLowerCase() == 'exp')
                              expressDelivery,
                            deliveryTypeIcon(
                              context,
                              invoice['delivery_type'],
                              invoice['deliverySalesPerson'],
                            ),

                            HoldCancelInfo(
                              invoiceCurrentStatus:
                                  invoice['invoice_status_int'],
                              holdStatus: invoice['holdStatus'],
                              holdAt: invoice['holdAt'],
                              holdReason: invoice['holdReason'],
                              holdReschedule: invoice['holdReschedule'],
                            ),
                            if (invoice['cod_flag'] == 1 &&
                                invoice['delivery_type'] != null &&
                                (invoice['delivery_type'] ==
                                        'Customer Collection' ||
                                    invoice['delivery_type'] == 'Courier'))
                              buildFlag(
                                invoice['payment_status'],
                                parseColor(invoice['payment_status_color']),
                              ),

                            if (invoice['other_branch_del'] == 1)
                              otherBranchDelivery(
                                size: 20,
                                color: Colors.purpleAccent,
                              ),
                          ],
                        ),
                      ),
                      Wrap(
                        spacing: 1.0,
                        runSpacing: 1.0,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // _buildPdfIcons(context, invoice, 0, isDisabled),
                          CommonPdfIcons(
                            context: context,
                            invoice: invoice,
                            startKm: 0,
                            isDisabled: isDisabled,
                            screenType: PdfIconScreenType.crm,
                          ),

                          if (invoice['invoice_status_int'] != null &&
                              (invoice['invoice_status_int'] <= 4 ||
                                  invoice['invoice_status_int'] == 11))
                            InkWell(
                              onTap: () => _openStatusPopup(invoice, index),
                              child: Icon(
                                iconData,
                                size: 28,
                                color:
                                    (iconData == Icons.no_encryption)
                                        ? Colors.blue
                                        : Colors.red,
                              ),
                            ),
                          if (invoice['invoice_status_int'] != null &&
                              (invoice['invoice_status_int'] <= 4 ||
                                  invoice['invoice_status_int'] == 11) &&
                              invoice['trip_id'] == 0)
                            InkWell(
                              onTap:
                                  () => _openDeliveryTypePopup(
                                    invoice['delivery_type'],
                                    invoice['invoice_id'],
                                    index,
                                  ),
                              child: Icon(
                                deliveryTypeIconData,
                                size: 28,
                                color:
                                    (deliveryTypeIconData == Icons.fire_truck)
                                        ? Colors.blue
                                        : Colors.red,
                              ),
                            ),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => CRMInvoiceTimeLine(
                                        invoice: invoice,
                                        index: index,
                                      ),
                                ),
                              );
                            },
                            child: Icon(
                              Icons.access_time,
                              color: Colors.green,
                              size: 28,
                            ),
                          ),
                          if (isDeliveryCompleted) ...[
                            // const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                showInfoDialog(
                                  context: context,
                                  title: 'Closing Remarks',
                                  message: invoice['delivery_remarks'],
                                );
                              },
                              child: const Icon(
                                Icons.info_outline,
                                size: 30,
                                color: Colors.blueGrey,
                              ),
                            ),
                          ],
                          if (isVisible) ...[
                            const SizedBox(width: 3),
                            GestureDetector(
                              onTap:
                                  (signUpdating[invoiceId] == true ||
                                          !canToggle)
                                      ? null // This is the condition you wanted to ensure was here
                                      : () async {
                                        final confirm = await showConfirmDialog(
                                          context,
                                          getConfirmMessage(
                                            invoice['sign_only'],
                                          ),
                                        );

                                        if (confirm) {
                                          _toggleSignOnly(invoice, index);
                                        }
                                      },
                              child:
                                  signUpdating[invoiceId] == true
                                      ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        _getSignIcon(invoice['sign_only']),
                                        // Grey out the icon if it's not toggleable
                                        color:
                                            !canToggle
                                                ? Colors.grey
                                                : _getSignColor(
                                                  invoice['sign_only'],
                                                ),
                                        size: 28,
                                      ),
                            ),
                          ],
                          /*if (invoice['invoice_status_int'] != null &&
                              canToggle) ...[
                            const SizedBox(width: 3),
                            GestureDetector(
                              onTap:
                                  (signUpdating[invoiceId] == true ||
                                          !canToggle)
                                      ? null
                                      : () async {
                                        final confirm = await showConfirmDialog(
                                          context,
                                          getConfirmMessage(
                                            invoice['sign_only'],
                                          ),
                                        );

                                        if (confirm) {
                                          _toggleSignOnly(invoice, index);
                                        }
                                      },
                              //: () => _toggleSignOnly(invoice, index),
                              child:
                                  signUpdating[invoiceId] == true
                                      ? SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Icon(
                                        _getSignIcon(invoice['sign_only']),
                                        color: _getSignColor(
                                          invoice['sign_only'],
                                        ),
                                        size: 28,
                                      ),
                            ),
                          ],*/
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // -------- EXPANDED BODY --------
          if (expandedIndex == index)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Items:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  // Use the local 'items' list for rendering
                  if (items.isNotEmpty)
                    Column(
                      children:
                          items
                              .map(
                                (item) => ListTile(
                                  title: Text(item['item_name'] ?? ''),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${item['item_sku'] ?? ''}'),
                                      Text('${item['item_sno'] ?? ''}'),
                                      Text(
                                        'Qty: ${item['item_qty'] ?? ''}',
                                        style: const TextStyle(
                                          color: primaryTeal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  if (items.isEmpty)
                    const Text(
                      'No items in this invoice.',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
