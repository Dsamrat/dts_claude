import 'dart:convert';

import 'package:dts/screens/view_payment_form.dart';
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

import '../utils/pusher_connector_interface.dart' as connector_interface;
import '../utils/pusher_connector_stub_impl.dart'
    if (dart.library.js) '../utils/pusher_connector_web_impl.dart'
    if (dart.library.io) '../utils/pusher_connector_stub_impl.dart'
    as connector_impl;
import '../widgets/pdf_widgets/delivery_type_icon.dart';
import 'crm_invoice_timeline.dart';
import 'invoice_page.dart';
import 'invoice_sign_page.dart';
import 'make_payment_form.dart';

class SalesHomeScreen extends StatefulWidget {
  final int? initialFilterOption;
  final int? initialBranchId;
  final String? initialStart;
  final String? initialEnd;
  final String? initialPage;

  const SalesHomeScreen({
    super.key,
    this.initialFilterOption,
    this.initialBranchId,
    this.initialStart,
    this.initialEnd,
    this.initialPage,
  });

  @override
  State<SalesHomeScreen> createState() => _SalesHomeScreenState();
}

// class _SalesHomeScreenState extends State<SalesHomeScreen> {
class _SalesHomeScreenState extends State<SalesHomeScreen>
    with SingleTickerProviderStateMixin {
  /* User & Filters */
  int? currentUserId;
  int? currentUserBranchId;
  int? userDepartmentId;
  int? isMultiBranch;
  int? totalResults;
  int? selectedBranchId;
  DateTime? startDate;
  DateTime? endDate;
  /*pagination*/
  int currentPage = 1;
  bool isLoading = false; // initial & refresh loading
  bool _isLoadingMore = false; // pagination spinner
  bool _hasNextPage = true;

  List<Map<String, dynamic>> invoices = [];
  final ScrollController _scrollController = ScrollController();
  /*pagination*/

  /* Data */
  List<Branch> branchesDrop = [];

  List<dynamic> assignedInvoices = [];

  bool isAssignedInvoicesLoading = false;

  final CrmService _crmService = CrmService();
  final InvoiceService _invoiceService = InvoiceService();
  final BranchService _branchService = BranchService();
  final TextEditingController _searchController = TextEditingController();
  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;
  bool _expanded = false;
  int? expandedIndex;

  // 1. Define the state variable for the toggle
  FilterOption? selectedFilter;

  @override
  void initState() {
    super.initState();
    /*pagination*/
    _scrollController.addListener(_onScroll);
    /*pagination*/
    // Initialize the controller with 2 tabs
    _tabController = TabController(length: 2, vsync: this);
    _pusherConnector = connector_impl.createPusherConnector();
    _initialize();
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
  bool showFilters = false;
  late TabController _tabController;
  // 2. Define your logic methods HERE (Above initState)
  Future<void> fetchCrmInvoices({bool reset = false}) async {
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
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to load invoice error: $e');
      }
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchSalesInvoices({List<int>? invoiceIds}) async {
    print('test reach sales Invoices');

    if (currentUserId == null) return;

    setState(() => isAssignedInvoicesLoading = true);

    try {
      final result = await _crmService.fetchSalesInvoices(
        userId: currentUserId,
      );

      if (!mounted) return;

      setState(() {
        if (result["status"] == "success") {
          assignedInvoices = List<Map<String, dynamic>>.from(
            result["data"],
          ); // ⬅ FIX
        }

        if (result["status"] == "missing") {
          final missing = result["missing"] as List<int>;
          assignedInvoices.removeWhere(
            (inv) => missing.contains(inv["invoice_id"]),
          );
        }

        isAssignedInvoicesLoading = false;
      });
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ ERROR in fetch `Assigned to Me` Invoices: $e');
        print(stack);
      }

      if (!mounted) return;
      setState(() => isAssignedInvoicesLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to load `Assigned to Me` invoices'),
        ),
      );
    }
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

  void _initializePusherWeb() {
    final channelNameWeb = 'sales-$currentUserBranchId';
    const String eventNameWeb = 'sales.created'; // Example dynamic value

    _pusherConnector.initPusherWeb(
      channelNameWeb, // Pass the channel prefix
      eventNameWeb, // Pass the event name
      _handlePusherEventWeb,
    );
  }

  Future<void> _handlePusherEventWeb(dynamic raw) async {
    try {
      await fetchSalesInvoices();
    } catch (e, st) {
      debugPrint("❌ Error in _handlePusherEventWeb: $e");
      debugPrint("$st");
    }
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

  Future<void> _initPusher() async {
    final pusherService = PusherService(
      apiKey: pusherAPIKey,
      cluster: pusherCluster,
      authEndpoint: pusherAuthURl,
      userToken: 'strinmg',
    );

    final channelName = 'sales-$currentUserId';
    debugPrint("📡 Subscribing to Pusher channel: $channelName");

    // ✅ Async callback for Pusher event
    pusherService.on(channelName, 'sales.created', (data) async {
      debugPrint("sales created event received: $data");
      await fetchSalesInvoices();
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
      fetchCrmInvoices(reset: true);
      fetchSalesInvoices();
    }
  }

  @override
  void dispose() {
    /*pagination*/
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    /*pagination*/
    _tabController.dispose();
    super.dispose();
  }

  Widget _allInvoicesList() {
    return RefreshIndicator(
      onRefresh: () => fetchCrmInvoices(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 🔹 Filters ALWAYS visible
          SliverToBoxAdapter(
            child: Column(
              children: [
                // FilterHeader(totalResults: totalResults ?? 0),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 1,
                  ),
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
                      IconButton(
                        icon: Icon(
                          showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                          color: Colors.teal,
                        ),
                        tooltip: showFilters ? "Hide Filters" : "Show Filters",
                        // onPressed: onToggle,
                        onPressed: () {
                          setState(() => showFilters = !showFilters);
                        },
                      ),
                    ],
                  ),
                ),
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

          // 🔹 Initial loading
          if (isLoading && invoices.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          // 🔹 Empty result (AFTER loading)
          else if (!isLoading && invoices.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  "No records found",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          // 🔹 List
          else
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == invoices.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return _buildInvoiceItem(invoices[index], index, 0);
              }, childCount: invoices.length + (_isLoadingMore ? 1 : 0)),
            ),
        ],
      ),
    );
  }

  Widget _allInvoicesListOld() {
    if (isLoading && invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: () => fetchCrmInvoices(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
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
          if (isLoading && invoices.isEmpty)
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
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index == invoices.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final invoice = invoices[index];
                return _buildInvoiceItem(invoices[index], index, 0);
              }, childCount: invoices.length + (_isLoadingMore ? 1 : 0)),
            ),
        ],
      ),
    );
  }

  Widget _assignedInvoicesList() {
    if (assignedInvoices.isEmpty) {
      return const Center(
        child: Text(
          "No records found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        // 🔹 Total records header
        FilterHeader(totalResults: assignedInvoices.length ?? 0),
        // 🔹 List with pull-to-refresh
        Expanded(
          child: RefreshIndicator(
            onRefresh: fetchSalesInvoices,
            child: ListView.separated(
              padding: const EdgeInsets.all(8),
              itemCount: assignedInvoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 2),
              itemBuilder:
                  (context, index) =>
                      _buildInvoiceItem(assignedInvoices[index], index, 1),
            ),
          ),
        ),
      ],
    );
  }
  // lib/screens/sales_home_screen.dart

  /* Widget _buildInvoiceItem(
    Map<String, dynamic> invoice,
    int index,
    int signPDF,
  ) {
    return CommonInvoiceItem(
      invoice: invoice,
      config: InvoiceItemConfig(
        screenType: InvoiceScreenType.sales,
        index: index,
        expandedIndex: expandedIndex,
        signPDF: signPDF,
        onExpansionChanged: (idx) {
          setState(() {
            expandedIndex = expandedIndex == idx ? null : idx;
          });
        },
        onOpenMap: _openMap,
        onOpenTimeline: (inv, idx) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CRMInvoiceTimeLine(invoice: inv, index: idx),
            ),
          );
        },
        onMakePayment: (inv) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MakePaymentForm(
                    invoiceId: int.parse(inv['invoice_id'].toString()),
                    docNum: inv['doc_num'],
                    invoiceAmount: inv['invoice_amount'],
                    deliveryType: inv['delivery_type'],
                    salesType: inv['sales_type'],
                  ),
            ),
          );
        },
        onViewPayment: (inv) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ViewPaymentForm(invoice: inv),
            ),
          );
        },
      ),
    );
  }*/
  Widget _buildInvoiceItem(
    Map<String, dynamic> invoice,
    int index,
    int signPDF,
  ) {
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ?? [];
    final isDisabled = false;
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
                          /*_buildPdfIcons(
                            context,
                            invoice,
                            0,
                            isDisabled,
                            signPDF,
                          ),*/
                          CommonPdfIcons(
                            context: context,
                            invoice: invoice,
                            startKm: 0,
                            isDisabled: isDisabled,
                            screenType: PdfIconScreenType.sales,
                            signPDF: signPDF,
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
                        ],
                      ),
                    ],
                  ),
                  if (invoice['cod_flag'] == 1 && signPDF == 1)
                    Row(
                      children: [
                        if (invoice['cod_status'] == 0)
                          TextButton.icon(
                            onPressed:
                                (isDisabled)
                                    ? null // disables button
                                    : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) => MakePaymentForm(
                                                invoiceId: int.parse(
                                                  invoice['invoice_id']
                                                      .toString(),
                                                ),
                                                docNum: invoice['doc_num'],
                                                invoiceAmount:
                                                    invoice['invoice_amount'],
                                                deliveryType:
                                                    invoice['delivery_type'],
                                                salesType:
                                                    invoice['sales_type'],
                                              ),
                                        ),
                                      );
                                    },
                            icon: Icon(
                              Icons.receipt,
                              color: (isDisabled) ? Colors.grey : Colors.red,
                            ),
                            label: Text(
                              'Update Payment Info.',
                              style: TextStyle(
                                color: (isDisabled) ? Colors.grey : Colors.red,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  EdgeInsets.zero, // removes default padding
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                        else
                          TextButton.icon(
                            onPressed: () {
                              // Navigate to payment screen
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          ViewPaymentForm(invoice: invoice),
                                ),
                              );
                            },
                            icon: const Icon(Icons.receipt, color: Colors.blue),
                            label: const Text(
                              'View Payment',
                              style: TextStyle(color: Colors.blue),
                            ),
                            style: TextButton.styleFrom(
                              padding:
                                  EdgeInsets.zero, // removes default padding
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const Navbar(title: "Sales Deliveries"),
      drawer: const ArgonDrawer(currentPage: "Deliveries"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          Column(
            children: [
              /// ✅ TabBar (Stays at the top)
              Material(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.teal,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.teal,
                  tabs: [
                    const Tab(text: 'All Invoices'),

                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Assigned to Me'),

                          const SizedBox(width: 6),

                          // 🔴 Red dot when count > 0
                          if (assignedInvoices.isNotEmpty)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              /// ✅ TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    /// 🔹 TAB 1: All Invoices (Includes Filter Toggle)
                    _allInvoicesList(),

                    /// 🔹 TAB 2: Assigned to Me (No filter toggle here)
                    isAssignedInvoicesLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _assignedInvoicesList(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /*Widget _buildPdfIcons(
    BuildContext context,
    Map<String, dynamic> invoice,
    int startKm, // Changed to int since it's parsed to int
    isDisabled,
    int signPDF,
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
        final int startKiloMeter = 10;
        final int? pdfId = pdfJson['pdf_id'] as int?;

        if (linkToOpen?.isNotEmpty == true) {
          pdfWidgets.add(
            IgnorePointer(
              ignoring: isDisabled,
              child: InkWell(
                onTap: () {
                  final resolvedDocNum = pdfJson['resolved_doc_num'];
                  final String resolved =
                      resolvedDocNum?.toString().trim() ?? "";

                  if (signPDF == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => InvoiceSignPage(
                              pdfLink: linkToOpen!,
                              docType: docType!,
                              invoiceNum:
                                  pdfJson['resolved_doc_num']?.toString() ??
                                  'N/A',
                              invoiceId: invoice['invoice_id'],
                              customerId: invoice['customer_id'],
                              cusLatitude: invoice['customer_latitude'],
                              cusLongitude: invoice['customer_longitude'],
                              pdfId: pdfId ?? 0,
                              startKiloMeter: startKiloMeter!,
                              signedPdfLink: signedPdfLink,
                              docLocation: invoice['doc_loc_id'],
                            ),
                      ),
                    );
                  } else {
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
                  }
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
  }*/
}
