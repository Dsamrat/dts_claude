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
import '../services/accounts_service.dart';
import '../services/branch_service.dart';
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
import '../widgets/pdf_widgets/delivery_type_icon.dart';
import 'invoice_sign_page.dart';
import 'make_payment_form.dart';

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

class AccountsHomeScreen extends StatefulWidget {
  final int? initialFilterOption;
  final int? initialBranchId;
  final String? initialStart;
  final String? initialEnd;
  final String? initialPage;

  const AccountsHomeScreen({
    super.key,
    this.initialFilterOption,
    this.initialBranchId,
    this.initialStart,
    this.initialEnd,
    this.initialPage,
  });

  @override
  State<AccountsHomeScreen> createState() => _AccountsHomeScreenState();
}

class _AccountsHomeScreenState extends State<AccountsHomeScreen> {
  /* User & Filters */
  int? currentUserId;
  int? currentUserBranchId;
  int? userDepartmentId;
  bool isMultiBranch = false;
  bool showFilters = false;

  /*pagination*/
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

  FilterOption? selectedFilter;

  /* Data */

  /* Services */
  final AccountsService _accountsService = AccountsService();
  final BranchService _branchService = BranchService();
  final TextEditingController _searchController = TextEditingController();
  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;

  @override
  void initState() {
    super.initState();
    /*pagination*/
    _scrollController.addListener(_onScroll);
    /*pagination*/
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
    if (_isLoadingMore || !_hasNextPage) return;
    setState(() => _isLoadingMore = true);
    currentPage++;

    await fetchAccountsInvoices(); /*page: currentPage*/
    if (mounted) {
      setState(() => _isLoadingMore = false);
    }
  }

  /*pagination*/

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
      userToken: '',
    );
    final channelName = 'accounts-$currentUserBranchId';

    pusherService.on(channelName, 'accounts.created', (data) async {
      debugPrint(
        "📡 Event received on channel '$channelName': accounts.created, Data: $data",
      );

      final Map<String, dynamic> eventPayload =
          jsonDecode(data.toString()) as Map<String, dynamic>;

      await onPusherEventReceivedWeb(eventPayload);
    });

    await pusherService.init();
  }

  void _initializePusherWeb() {
    final channelNameWeb = 'accounts-$currentUserBranchId';
    const String eventNameWeb = 'accounts.created'; // Example dynamic value

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

      /*Map<String, dynamic> eventPayload;

      if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        eventPayload = Map<String, dynamic>.from(decoded.first);
      } else if (decoded is Map) {
        eventPayload = Map<String, dynamic>.from(decoded);
      } else {
        debugPrint("❌ Unexpected Pusher payload format: $decoded");
        return;
      }

      await onPusherEventReceivedWeb(eventPayload);*/
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

    if (invoiceIds.isEmpty) {
      return UpdateSummary(0, 0);
    }

    debugPrint('📦 Invoice IDs from Pusher: $invoiceIds');

    final res = await _accountsService.fetchAccountsInvoices(
      page: 1,
      invoiceIds: invoiceIds,
      filter: selectedFilter?.key.toString() ?? '0',
      userBranchId: selectedBranchId,
      search: _searchController.text,
      startDate: startDate?.toIso8601String(),
      endDate: endDate?.toIso8601String(),
    );

    // ✅ THIS LINE WAS MISSING
    final List<dynamic> fetchedInvoices = res['invoices']['data'];

    int inserted = 0;
    int updated = 0;

    for (final newInvoice in fetchedInvoices) {
      final index = invoices.indexWhere(
        (i) => i['invoice_id'] == newInvoice['invoice_id'],
      );

      if (index == -1) {
        invoices.insert(0, newInvoice);
        inserted++;
      } else {
        invoices[index] = newInvoice;
        updated++;
      }
    }

    if (mounted) setState(() {});

    return UpdateSummary(inserted, updated);
  }

  Future<void> _loadUserDetails() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      currentUserBranchId = prefs.getInt('branchId');
      currentUserId = prefs.getInt('userId');
      userDepartmentId = prefs.getInt('departmentId');
      isMultiBranch = prefs.getInt('multiBranch') == 1;
      // selectedBranchId = widget.initialBranchId ?? currentUserBranchId;
      selectedBranchId =
          (widget.initialPage == 'Home')
              ? widget.initialBranchId
              : currentUserBranchId;
    });

    // Setup filters
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
    if (widget.initialStart != null)
      startDate = DateTime.parse(widget.initialStart!);
    if (widget.initialEnd != null) endDate = DateTime.parse(widget.initialEnd!);

    if (isMultiBranch) {
      branchesDrop = await _branchService.getBranches();
    }

    if (currentUserId != null) {
      fetchAccountsInvoices();
    }
  }

  Future<void> fetchAccountsInvoices({
    List<int>? invoiceIds,
    bool reset = false,
  }) async {
    if (isLoading) return;

    if (reset) {
      currentPage = 1;
      invoices.clear();
      _hasNextPage = true;
    }

    if (!_hasNextPage) return;

    setState(() => isLoading = true);

    try {
      final res = await _accountsService.fetchAccountsInvoices(
        page: currentPage,
        invoiceIds: invoiceIds,
        filter: selectedFilter?.id.toString() ?? '0',
        userBranchId: selectedBranchId,
        search: _searchController.text,
        startDate: startDate?.toIso8601String(),
        endDate: endDate?.toIso8601String(),
      );
      debugPrint(res.toString());
      if (!mounted) return;

      final container = res['invoices'];
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

  Widget _allInvoicesList() {
    // Show full screen loader ONLY on first load/reset
    if (isLoading && invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () => fetchAccountsInvoices(reset: true),
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
                    fetchAccountsInvoices(reset: true);
                  },
                  isMultiBranch: isMultiBranch ? 1 : 0,
                  branchesDrop: branchesDrop,
                  selectedBranchId: selectedBranchId,
                  onBranchChanged: (branch) {
                    setState(() {
                      selectedBranchId = branch?.id;
                      currentPage = 1;
                      invoices.clear();
                    });
                    fetchAccountsInvoices(reset: true);
                  },
                  searchController: _searchController,
                  onSearch: () {
                    currentPage = 1;
                    invoices.clear();
                    fetchAccountsInvoices(reset: true);
                  },
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                    currentPage = 1;
                    invoices.clear();
                    fetchAccountsInvoices(reset: true);
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
                    fetchAccountsInvoices(reset: true);
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

                  return _buildInvoiceItem(invoices[index]);
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
        final int startKiloMeter = 10; // Already an int
        final String? signedPdfLink = pdfJson['signed_pdf_link'] as String?;
        final int? pdfId = pdfJson['pdf_id'] as int?;
        final String? linkToOpen =
            signedPdfLink?.isNotEmpty == true ? signedPdfLink : pdfLink;

        if (linkToOpen?.isNotEmpty == true) {
          pdfWidgets.add(
            IgnorePointer(
              ignoring: isDisabled,
              child: InkWell(
                onTap: () {
                  /*HERE WE HAVE TO PASS TO GET SIGNATURE*/
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => InvoiceSignPage(
                            pdfLink:
                                linkToOpen ??
                                '', // Handle potential null linkToOpen
                            docType:
                                docType ?? '', // Handle potential null docType
                            invoiceNum:
                                pdfJson['resolved_doc_num']?.toString() ??
                                'N/A',
                            invoiceId: invoice['invoice_id'],
                            customerId: invoice['customer_id'],
                            cusLatitude: invoice['customer_latitude'],
                            cusLongitude: invoice['customer_longitude'],
                            pdfId:
                                pdfId ??
                                0, // Handle potential null pdfId, provide a default
                            startKiloMeter:
                                startKiloMeter, // This is now a non-nullable int (10)
                            signedPdfLink: signedPdfLink,
                            docLocation: invoice['doc_loc_id'],
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
  // lib/screens/accounts_home_screen.dart

  /*Widget _buildInvoiceItem(Map<String, dynamic> invoice) {
    return CommonInvoiceItem(
      invoice: invoice,
      config: InvoiceItemConfig(
        screenType: InvoiceScreenType.accounts,
        onOpenMap: _openMap,
        onMakePayment: (inv) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => MakePaymentForm(
                    invoiceId: inv['invoice_id'],
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
  Widget _buildInvoiceItem(Map<String, dynamic> invoice) {
    final List<dynamic> items = (invoice['items'] as List<dynamic>?) ?? [];

    final isDisabled = isInvoiceDisabled(
      invoice['invoice_status_int'],
      invoice['holdStatus'],
      'test',
    );
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
      child: ExpansionTile(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                buildFlag(
                  (invoice['invoice_status'] ?? 'Unknown').replaceAll(
                    '\\n',
                    '\n',
                  ),

                  getStatusColor(invoice['invoice_status_int']),
                ),
              ],
            ),
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
                      (invoice['customer_name'] as String?)?.toTitleCase() ??
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
                      const SnackBar(content: Text("Location not available")),
                    );
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    // Build text only if there’s something to show
                    if ((invoice['cus_distance'] != null &&
                            invoice['cus_distance'].toString().isNotEmpty &&
                            invoice['cus_distance'].toString().toLowerCase() !=
                                'unknown') ||
                        (invoice['subLocality'] != null &&
                            invoice['subLocality'].toString().isNotEmpty))
                      Text(
                        [
                          // if distance exists and not 'unknown'
                          if (invoice['cus_distance'] != null &&
                              invoice['cus_distance'].toString().isNotEmpty &&
                              invoice['cus_distance']
                                      .toString()
                                      .toLowerCase() !=
                                  'unknown')
                            invoice['cus_distance'].toString(),
                          // if subLocality'] exists
                          if (invoice['subLocality'] != null &&
                              invoice['subLocality'].toString().isNotEmpty)
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
                        style: TextStyle(fontSize: 14, color: Colors.grey),
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
            if (invoice['order_id'] != null && invoice['order_id'].isNotEmpty)
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
                      style: TextStyle(fontSize: 14, color: Colors.black87),
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
                  const Icon(Icons.message, size: 18, color: secondaryTeal),
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
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const SizedBox(height: 8),
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
                        invoiceCurrentStatus: invoice['invoice_status_int'],
                        holdStatus: invoice['holdStatus'],
                        holdAt: invoice['holdAt'],
                        holdReason: invoice['holdReason'],
                        holdReschedule: invoice['holdReschedule'],
                      ),
                      if (invoice['cod_flag'] == 1 &&
                          (invoice['delivery_type'] == 'Customer Collection' ||
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
                  // children: [_buildPdfIcons(context, invoice, 0, isDisabled)],
                  children: [
                    CommonPdfIcons(
                      context: context,
                      invoice: invoice,
                      startKm: 0,
                      isDisabled: isDisabled,
                      screenType: PdfIconScreenType.accounts,
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
                  ],
                ),
              ],
            ),

            // const SizedBox(height: 8),
            // Receipt row
            if (invoice['cod_flag'] == 1)
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
                                          invoiceId: invoice['invoice_id'],
                                          docNum: invoice['doc_num'],
                                          invoiceAmount:
                                              invoice['invoice_amount'],
                                          deliveryType:
                                              invoice['delivery_type'],
                                          salesType: invoice['sales_type'],
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
                        padding: EdgeInsets.zero, // removes default padding
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
                                (context) => ViewPaymentForm(invoice: invoice),
                          ),
                        );
                      },
                      icon: const Icon(Icons.receipt, color: Colors.blue),
                      label: const Text(
                        'View Payment',
                        style: TextStyle(color: Colors.blue),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero, // removes default padding
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
          ],
        ),

        children: [
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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

//END OF FILE - Samrat - Nagoor S
