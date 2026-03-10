import 'dart:async';
import 'dart:convert';
import 'package:dts/widgets/home_widgets/filter_header.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dts/models/filter_option.dart';
import 'package:dts/models/invoice.dart';
import 'package:dts/models/branch.dart';
import 'package:dts/services/invoice_service.dart';
import 'package:dts/services/branch_service.dart';
import 'package:dts/widgets/navbar.dart';
import 'package:dts/widgets/drawer.dart';
import '../constants/common.dart';
import '../services/crm_service.dart';
import '../services/pusher_service.dart';
import '../widgets/build_invoice_card.dart';
import '../widgets/home_widgets/FilterIcon.dart';
import '../widgets/home_widgets/FilterSection.dart';
import 'accounts_home_screen.dart';
import 'invoice_det.dart';
import 'pick_home_screen.dart';
import 'driver_home_screen.dart';

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

class HomeScreen extends StatefulWidget {
  final int? initialFilterOption;
  final int? initialBranchId;
  final String? initialStart;
  final String? initialEnd;
  final String? initialPage;

  const HomeScreen({
    super.key,
    this.initialFilterOption,
    this.initialBranchId,
    this.initialStart,
    this.initialEnd,
    this.initialPage,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? isMultiBranch;
  int? userBranchId;
  int? userActualBranchId;
  int? userDepartmentId;
  int? currentUserId;
  String userToken = 'test';
  int? totalResults;
  bool showFilters = false;
  List<Branch> branchesDrop = [];
  FilterOption? selectedFilter;

  String selectedGroup = 'Invoice';
  int? selectedBranchId;

  List<Invoice> invoices = [];
  int currentPage = 1;
  bool isLoading = false;
  bool isDataLoaded = false;
  bool _isLoadingMore = false;
  bool _hasNextPage = true;
  final ScrollController scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  Map<int, bool> signUpdating = {}; // Loader map per invoice
  final InvoiceService _invoiceService = InvoiceService();
  final BranchService _branchService = BranchService();
  final CrmService _crmService = CrmService();

  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;

  DateTime? startDate;
  DateTime? endDate;

  @override
  void initState() {
    super.initState();

    _pusherConnector = connector_impl.createPusherConnector();
    scrollController.addListener(_onScroll);
    _initialize();
  }

  void _onScroll() {
    if (_hasNextPage && !_isLoadingMore) {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent) {
        _loadMoreInvoices();
      }
    }
  }

  Future<void> _loadMoreInvoices() async {
    setState(() => _isLoadingMore = true);
    currentPage++;
    await fetchInvoices(page: currentPage);
    setState(() => _isLoadingMore = false);
  }

  // -------------------- TOGGLE SIGN ONLY --------------------
  Future<void> _toggleSignOnly(Invoice invoice, int index) async {
    final int invoiceId = invoice.id ?? 0;
    final int currentValue = invoice.signOnly ?? 0;
    final int newValue = currentValue == 1 ? 0 : 1;

    final int currentStatus = invoice.invoiceCurrentStatus ?? 0;
    // 🔒 Save original values (for rollback)
    final int originalSignOnly = currentValue;
    final int originalStatus = currentStatus;
    final int originalTripId = invoice.tripID;
    // 🔥 Start loader
    setState(() => signUpdating[invoiceId] = true);
    // ⚡ Optimistic UI update
    setState(() {
      invoices[index].signOnly = newValue;

      // Case 1: signOnly=1 and status=5 or 6 → status becomes 1
      if (currentValue == 1 && (currentStatus == 5 || currentStatus == 6)) {
        invoices[index].invoiceCurrentStatus = 1;
        invoices[index].invoiceStatus = Invoice.mapStatus(1);
        invoices[index].tripID = 0;
      }
      // Case 2: signOnly=0 and status=1 → status becomes 5
      else if (currentValue == 0 && currentStatus == 1) {
        invoices[index].invoiceCurrentStatus = 5;
        invoices[index].invoiceStatus = Invoice.mapStatus(5);
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
          invoices[index].signOnly = originalSignOnly;
          invoices[index].invoiceCurrentStatus = originalStatus;
          invoices[index].invoiceStatus = Invoice.mapStatus(originalStatus);
          invoices[index].tripID = originalTripId;
        });
      }
    } catch (e) {
      success = false;
      // ❌ Exception → rollback
      setState(() {
        invoices[index].signOnly = originalSignOnly;
        invoices[index].invoiceCurrentStatus = originalStatus;
        invoices[index].invoiceStatus = Invoice.mapStatus(originalStatus);
        invoices[index].tripID = originalTripId;
      });
    }
    // 🔥 Stop loader
    setState(() => signUpdating.remove(invoiceId));

    // SnackBar
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

  Future<void> _initialize() async {
    await loadUserDetails();
    if (kIsWeb && !_pusherInitialized) {
      _initializePusherWeb();
      _pusherInitialized = true;
    } else if (!kIsWeb) {
      await initPusher();
    }
  }

  void _initializePusherWeb() {
    final channelNameWeb = 'invoices-$userBranchId';
    const String eventNameWeb = 'invoice.created'; // Example dynamic value

    _pusherConnector.initPusherWeb(
      channelNameWeb, // Pass the channel prefix
      eventNameWeb, // Pass the event name
      _handlePusherEventWeb,
    );
  }

  // Separate async handler
  Future<void> _handlePusherEventWeb(dynamic raw) async {
    try {
      debugPrint('reached _handlePusherEventWeb');
      final decoded = jsonDecode(
        raw.toString(),
      ); // 👈 convert JSON string to Dart object
      Map<String, dynamic> eventPayload;

      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        eventPayload = Map<String, dynamic>.from(decoded.first);
      } else if (decoded is Map) {
        eventPayload = Map<String, dynamic>.from(decoded);
      } else {
        debugPrint("❌ Unexpected Pusher payload format: $decoded");
        return;
      }

      await onPusherEventReceivedWeb(eventPayload);
    } catch (e, st) {
      debugPrint("❌ Error in _handlePusherEventWeb: $e");
      debugPrint("$st");
    }
  }

  Future<void> onPusherEventReceivedWeb(
    Map<String, dynamic> eventPayload,
  ) async {
    final UpdateSummary summary = await _handleNewInvoiceFromPusher(
      eventPayload,
    );

    if (!mounted) return;

    if (summary.insertedCount > 0 || summary.updatedCount > 0) {
      final totalChanges = summary.insertedCount + summary.updatedCount;
      String message;

      if (summary.insertedCount > 0 && summary.updatedCount > 0) {
        message =
            '$totalChanges Invoices: ${summary.insertedCount} inserted, ${summary.updatedCount} updated.';
      } else if (summary.insertedCount > 0) {
        message =
            '${summary.insertedCount} New Invoice${summary.insertedCount > 1 ? 's' : ''} Inserted';
      } else {
        message =
            '${summary.updatedCount} Invoice${summary.updatedCount > 1 ? 's' : ''} Updated';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }

    setState(() {}); // Refresh UI
  }

  Future<UpdateSummary> _handleNewInvoiceFromPusher(
    Map<String, dynamic> eventData,
  ) async {
    debugPrint('reached _handleNewInvoiceFromPusher');
    // 🎯 CHANGE 1: Extract the List of invoice IDs from eventData
    final List<dynamic>? rawInvoiceIds = eventData['invoiceID'];
    if (rawInvoiceIds == null || rawInvoiceIds.isEmpty) {
      return UpdateSummary(0, 0);
    }

    // Cast the list to List<int> for the service call
    // final List<int> invoiceIds = rawInvoiceIds.cast<int>();

    final List<int> invoiceIds =
        rawInvoiceIds
            .map((e) {
              if (e is int) return e;
              if (e is String) return int.tryParse(e) ?? 0;
              return 0;
            })
            .where((id) => id > 0)
            .toList();
    // 1. Trigger the API check using current filter values
    // 🎯 CHANGE 2: Pass the list of IDs instead of a single ID string
    final result = await _invoiceService.getInvoices(
      filter: selectedFilter?.id.toString() ?? '0',
      page: 1,
      isMultiBranch: isMultiBranch,
      userBranchId: selectedBranchId,
      userActualBranchId: userActualBranchId,
      currentUserId: currentUserId,
      search: _searchController.text,
      groupBy: selectedGroup,
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
      invoiceIds: invoiceIds,
    );

    // 🎯 CHANGE 3: Expect a list of Invoices (plural) from the result
    // ✅ FIX: invoices are already parsed
    final List<Invoice> matchedInvoices = result['invoices'] as List<Invoice>;

    int insertedCount = 0;
    int updatedCount = 0;

    for (final newInvoice in matchedInvoices) {
      final index = invoices.indexWhere((i) => i.id == newInvoice.id);

      if (index == -1) {
        invoices.insert(0, newInvoice);
        totalResults = (totalResults ?? 0) + 1;
        insertedCount++;
      } else {
        invoices[index] = newInvoice;
        updatedCount++;
      }
    }

    if (mounted && matchedInvoices.isNotEmpty) {
      setState(() {});
    }

    return UpdateSummary(insertedCount, updatedCount);
  }

  // A separate function to handle loading more items

  Future<void> initPusher() async {
    final pusherService = PusherService(
      apiKey: pusherAPIKey,
      cluster: pusherCluster,
      authEndpoint: pusherAuthURl,
      userToken: userToken,
    );

    final channelName = 'invoices-$userBranchId';
    debugPrint("📡 Subscribing to Pusher channel: $channelName");

    pusherService.on(channelName, 'invoice.created', (data) async {
      try {
        debugPrint("📦 Raw Pusher data: $data");

        final decoded = jsonDecode(data.toString());

        if (decoded is! Map<String, dynamic>) {
          debugPrint(
            "❌ Pusher payload error: Expected Map<String, dynamic>, got ${decoded.runtimeType}",
          );
          return;
        }

        await onPusherEventReceivedWeb(decoded);
      } catch (e, stackTrace) {
        debugPrint("❌ Error handling Pusher event: $e");
        debugPrint("StackTrace: $stackTrace");
      }
    });

    try {
      await pusherService.init();
    } catch (e, stackTrace) {
      debugPrint("❌ Pusher init failed: $e");
      debugPrint("StackTrace: $stackTrace");
    }
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isMultiBranch = prefs.getInt('multiBranch');
    userBranchId = prefs.getInt('branchId');
    userActualBranchId = prefs.getInt('branchId');
    userDepartmentId = prefs.getInt('departmentId');
    currentUserId = prefs.getInt('userId');
    // selectedBranchId = widget.initialBranchId ?? userBranchId;
    selectedBranchId =
        (widget.initialPage == 'Home') ? widget.initialBranchId : userBranchId;
    userToken = prefs.getString('token') ?? '';

    if (userDepartmentId == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PickHomeScreen()),
        );
      });
      return;
    }

    if (userDepartmentId == 7 || userDepartmentId == 8) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
        );
      });
      return;
    }
    if (userDepartmentId == 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AccountsHomeScreen()),
        );
      });
      return;
    }
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
    if (widget.initialStart != null)
      startDate = DateTime.parse(widget.initialStart!);
    if (widget.initialEnd != null) endDate = DateTime.parse(widget.initialEnd!);

    fetchInvoices(reset: true);
    setState(() {});
  }

  Future<void> fetchInvoices({bool reset = false, int? page}) async {
    if (reset) {
      currentPage = 1;
      invoices.clear();
      _hasNextPage = true;
    }
    if (!mounted) return;
    setState(() {
      isLoading = true;
      isDataLoaded = false;
    });
    try {
      final result = await _invoiceService.getInvoices(
        filter: selectedFilter?.id.toString() ?? '0',
        page: page ?? currentPage,
        isMultiBranch: isMultiBranch,
        userBranchId: selectedBranchId,
        userActualBranchId: userActualBranchId,
        currentUserId: currentUserId,
        search: _searchController.text,
        groupBy: selectedGroup,
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );

      final newInvoices = result['invoices'] as List<Invoice>;
      totalResults = result['total'] as int;

      // Check if the returned list is empty
      if (newInvoices.isEmpty) {
        _hasNextPage = false; // No more data to fetch
      }

      for (var invoice in newInvoices) {
        if (!invoices.any((inv) => inv.id == invoice.id)) {
          invoices.add(invoice);
        }
      }
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isDataLoaded = true;
      });
    } catch (e) {
      debugPrint("Error fetching invoices: $e");
      setState(() {
        isLoading = false;
        isDataLoaded = true;
      });
    }
  }

  void openInvoiceDet({Invoice? invoice}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDet(invoice: invoice)),
    );
    fetchInvoices(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: Navbar(
        title: "Deliveries",
        rightOptions: true,
        showFilter: true,
        filterEnabled: showFilters,
        onFilterPressed: () {
          setState(() => showFilters = !showFilters);
        },
      ),
      drawer: ArgonDrawer(currentPage: "Deliveries"),
      body:
          isLoading && currentPage == 1
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: () => fetchInvoices(reset: true),
                child: CustomScrollView(
                  controller: scrollController,
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
                              fetchInvoices();
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
                              fetchInvoices();
                            },

                            searchController: _searchController,
                            onSearch: () {
                              currentPage = 1;
                              invoices.clear();
                              fetchInvoices();
                            },
                            onClearSearch: () {
                              _searchController.clear();
                              setState(() {});
                              currentPage = 1;
                              invoices.clear();
                              fetchInvoices();
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
                              fetchInvoices();
                            },
                          ),
                        ],
                      ),
                    ),
                    if (isDataLoaded && invoices.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            "No records found",
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == invoices.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final invoice = invoices[index];
                            return _buildInvoiceCard(invoice, context, index);
                          },
                          childCount:
                              invoices.length + (_isLoadingMore ? 1 : 0),
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice, BuildContext context, index) {
    final bool enableOnTap = invoice.signOnly != 1;
    final bool canToggle =
        (invoice.signOnly == 1 &&
            (invoice.invoiceCurrentStatus == 5 ||
                invoice.invoiceCurrentStatus == 6)) ||
        (invoice.signOnly == 0 && invoice.invoiceCurrentStatus == 1);
    return buildInvoiceCard(
      invoice,
      context,
      screen: 'HomeScreen',
      onTap:
          enableOnTap
              ? () => openInvoiceDet(invoice: invoice)
              : null, // Set to null if signOnly is 1
      onToggleSignOnly:
          (canToggle) ? () => _toggleSignOnly(invoice, index) : null,
      signUpdating: signUpdating,
      wrapWithCard: true,
    );
  }
}
