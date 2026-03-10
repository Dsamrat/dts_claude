import 'package:dts/utils/string_extensions.dart';
import 'package:dts/widgets/hold_cancel_info.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/common.dart';
import '../models/branch.dart';
import '../screens/trip_form_screen.dart';
import '../services/branch_service.dart';
import '../services/expedition_service.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/build_flag.dart';
import '../widgets/drawer.dart';

import '../widgets/home_widgets/FilterSection.dart';
import '../widgets/navbar.dart';
import '../widgets/trip_status.dart';

import 'package:intl/intl.dart';

class ExpeditionScreen extends StatefulWidget {
  final int? highlightTripID;
  final int? initialTabIndex;
  const ExpeditionScreen({
    super.key,
    this.highlightTripID,
    this.initialTabIndex,
  });

  @override
  State<ExpeditionScreen> createState() => _ExpeditionScreenState();
}

class _ExpeditionScreenState extends State<ExpeditionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Define the controller
  List<dynamic> trips = [];
  // 1. Define the counts in your State class
  Map<String, int> tabCounts = {
    "Preparing": 0,
    "Dispatched": 0,
    "Completed": 0,
  };
  // --- LOADING STATES ---
  bool isInitialSetupDone = false; // Define it here
  Map<int, bool> isTabLoading = {0: false, 1: false, 2: false};

  // --- DATA STORAGE ---
  Map<int, List<dynamic>> tabData = {0: [], 1: [], 2: []};
  Map<int, int> tabPages = {0: 1, 1: 1, 2: 1};
  Map<int, bool> hasMore = {0: true, 1: true, 2: true};
  Map<int, bool> isLoading = {0: false, 1: false, 2: false};

  String currentSearch = "";

  final ExpeditionService _ExpeditionService = ExpeditionService();
  final BranchService _branchService = BranchService();
  int? currentUserBranchId;
  int? currentUserId;
  int? viewOnly;
  Set<int> _loadingItemIds = {};
  int? expandedTripID;
  bool showFilters = false;
  List<Branch> branchesDrop = [];
  int? selectedBranchId;
  int? userDepartmentId;
  DateTimeRange? dateRange;
  @override
  void initState() {
    super.initState();
    // Initialize controller with the passed index or default to 0
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    _tabController.addListener(_handleTabSelection);
    _initialize();
  }

  // REQUIRED: Handles loading data when user clicks a new tab
  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;

    // If the tab we just switched to has no data, fetch it
    int currentIndex = _tabController.index;
    if (tabData[currentIndex]!.isEmpty && !isTabLoading[currentIndex]!) {
      fetchTrips(tabIndex: currentIndex);
    }
  }

  // REQUIRED: The master setup function

  Future<void> _initialize() async {
    await _loadUserDetails();
    await loadInitialData();

    setState(() {
      expandedTripID = widget.highlightTripID;
      isInitialSetupDone = true;
    });

    // This will now fetch data for the CORRECT tab (e.g., Dispatched)
    fetchTrips(
      tabIndex: _tabController.index,
      highlightId: widget.highlightTripID,
    );
  }

  // Common Search Logic
  void onSearch(String value) {
    setState(() {
      currentSearch = value;
      // Reset all tabs because search applies globally
      tabData = {0: [], 1: [], 2: []};
      tabPages = {0: 1, 1: 1, 2: 1};
      hasMore = {0: true, 1: true, 2: true};
    });
    fetchTrips(tabIndex: _tabController.index);
  }

  @override
  void dispose() {
    _tabController.dispose(); // Always dispose controllers
    super.dispose();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    setState(() {
      currentUserBranchId = prefs.getInt('branchId');
      currentUserId = prefs.getInt('userId');
      selectedBranchId = prefs.getInt('branchId');
      userDepartmentId = prefs.getInt('departmentId');
      viewOnly = prefs.getInt('viewOnly');
      // isLoading = true;
    });

    if (currentUserBranchId != null && currentUserId != null) {
      try {
        // await fetchTrips(); // ✅ wait for fetchTrips to finish
        await fetchTrips(tabIndex: 0, isRefresh: true);
      } catch (e) {
        // print('Error loading trips: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load trips')));
      }
    }

    setState(() {
      // isLoading = false;
    });
  }

  Future<void> loadInitialData() async {
    branchesDrop = await _branchService.getBranches();
    if (selectedBranchId == null && branchesDrop.isNotEmpty) {
      selectedBranchId = branchesDrop.first.id;
    }
  }

  Future<void> fetchTrips({
    required int tabIndex,
    bool isRefresh = false,
    int? highlightId,
  }) async {
    // 1. Reset state if it's a new search or manual refresh
    if (isRefresh) {
      tabPages[tabIndex] = 1;
      hasMore[tabIndex] = true;
      tabData[tabIndex] = [];
    }

    // 2. Prevent redundant calls
    if (!hasMore[tabIndex]! || isLoading[tabIndex]!) return;

    setState(() => isLoading[tabIndex] = true);

    // 3. Map index to Status String
    String status =
        tabIndex == 0
            ? "Preparing"
            : (tabIndex == 1 ? "Dispatched" : "Completed");

    try {
      // 4. Call service with ALL required parameters
      final response = await _ExpeditionService.fetchTrips(
        currentUserBranchId: selectedBranchId!,
        currentUserId: currentUserId!,
        startDate:
            dateRange != null
                ? DateFormat('yyyy-MM-dd').format(dateRange!.start)
                : null,
        endDate:
            dateRange != null
                ? DateFormat('yyyy-MM-dd').format(dateRange!.end)
                : null,
        status: status,
        page: tabPages[tabIndex]!,
        search: currentSearch,
        highlightTripId: highlightId,
      );
      setState(() {
        // Update the list data
        if (isRefresh) {
          tabData[tabIndex] = response['data'];
        } else {
          tabData[tabIndex]!.addAll(response['data']);
        }

        // Update the Global Counts from the API response
        debugPrint('count ${response['counts']}');
        if (response['counts'] != null) {
          final countsData = Map<String, dynamic>.from(response['counts']);

          tabCounts = {
            "Preparing": countsData['Preparing'] ?? 0,
            "Dispatched": countsData['Dispatched'] ?? 0,
            "Completed": countsData['Completed'] ?? 0,
          };
        }
        tabPages[tabIndex] = tabPages[tabIndex]! + 1;
        hasMore[tabIndex] = response['has_more'];

        isLoading[tabIndex] = false;
      });
    } catch (e) {
      setState(() => isLoading[tabIndex] = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> updateItemLoadedStatus(
    int invoiceId,
    int itemId,
    bool isLoaded,
    Map<String, dynamic> item,
  ) async {
    final previousValue = item['item_loaded'];
    try {
      final dataToSend = {
        'currentUserBranchId': currentUserBranchId,
        'currentUserId': currentUserId,
        'invoiceId': invoiceId,
        'itemId': itemId,
        'isLoaded': isLoaded,
      };

      final response = await _ExpeditionService.updateItemLoaded(dataToSend);

      setState(() {
        // isLoading = false;
      });
      // print(response['tripId']);
      debugPrint('Trip ID: ${response['tripId']}');
      bool tripFound = false;
      for (int tabIndex = 0; tabIndex < 3; tabIndex++) {
        final tripIndex = tabData[tabIndex]!.indexWhere(
          (t) => t['trip_id'] == response['tripId'],
        );

        if (tripIndex != -1) {
          tripFound = true;
          debugPrint('Trip found in tab $tabIndex at index $tripIndex');

          final invoiceIndex = tabData[tabIndex]![tripIndex]['invoices']
              .indexWhere((inv) => inv['invoice_id'] == invoiceId);

          debugPrint('Invoice Index: $invoiceIndex');
          debugPrint('allItemsLoaded: ${response['allItemsLoaded']}');

          if (invoiceIndex != -1) {
            setState(() {
              if (response['allItemsLoaded'] == true) {
                tabData[tabIndex]![tripIndex]['invoices'][invoiceIndex]['invoice_status_int'] =
                    5;
                tabData[tabIndex]![tripIndex]['invoices'][invoiceIndex]['invoice_status'] =
                    'Loaded';
              } else {
                tabData[tabIndex]![tripIndex]['invoices'][invoiceIndex]['invoice_status_int'] =
                    4;
                tabData[tabIndex]![tripIndex]['invoices'][invoiceIndex]['invoice_status'] =
                    'Ready for Loading';
              }
            });
          }
          break; // Exit loop once trip is found and updated
        }
      }

      if (!tripFound) {
        debugPrint(
          '⚠️ Warning: Trip ID ${response['tripId']} not found in any tab',
        );
      }

      /*final tripIndex = trips.indexWhere(
        (t) => t['trip_id'] == response['tripId'],
      );
      debugPrint('Trip Index: $tripIndex');
      if (tripIndex != -1) {
        final invoiceIndex = trips[tripIndex]['invoices'].indexWhere(
          (inv) => inv['invoice_id'] == invoiceId,
        );
        debugPrint('Invoice Index: $invoiceIndex');
        debugPrint('allItemsLoaded: ${response['allItemsLoaded']}');
        if (invoiceIndex != -1) {
          if (response['allItemsLoaded'] == true) {
            trips[tripIndex]['invoices'][invoiceIndex]['invoice_status_int'] =
                5;
            trips[tripIndex]['invoices'][invoiceIndex]['invoice_status'] =
                'Loaded'; // optional update of string label
          } else {
            trips[tripIndex]['invoices'][invoiceIndex]['invoice_status_int'] =
                4;
            trips[tripIndex]['invoices'][invoiceIndex]['invoice_status'] =
                'Ready for Loading'; // optional update of string label
          }
        }
      }*/
    } catch (e) {
      // print('previousValue: ${item['item_loaded']}');
      setState(() {
        item['item_loaded'] = (item['item_loaded'] == 1) ? 0 : 1;
      });
      // print('Error fetching trips: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update trips')));
    }
  }

  Future<void> deleteTrip(int tripId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Delete Trip'),
            content: const Text('Are you sure you want to delete this trip?'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              TextButton(
                child: const Text('Delete'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _ExpeditionService.deleteTrip(tripId);
      //fetchTrips();
      await fetchTrips(tabIndex: 0, isRefresh: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip Deleted')));
    }
  }

  void _resetAllTabData() {
    tabData = {0: [], 1: [], 2: []};
    tabPages = {0: 1, 1: 1, 2: 1};
    hasMore = {0: true, 1: true, 2: true};
    // We keep tabCounts as is, or reset them to 0 until the next API response
  }

  // ------------------------
  // Filter trips by status
  // ------------------------
  List filteredTrips(String status) {
    return trips.where((trip) {
      final startKm = trip['start_km'];
      final endKm = trip['end_km'];

      final bool hasStartKm = startKm != null && startKm != 0;
      final bool hasEndKm = endKm != null && endKm != 0;

      String tripStatus;
      if (!hasStartKm && !hasEndKm) {
        tripStatus = 'Preparing';
      } else if (hasStartKm && !hasEndKm) {
        tripStatus = 'Dispatched';
      } else {
        tripStatus = 'Completed';
      }

      return tripStatus == status;
    }).toList();
  }

  // ------------------------
  // Build list of trips for a specific status
  // ------------------------
  Widget _buildTripListByStatus(int tabIndex) {
    final list = tabData[tabIndex]!;
    final bool loading = isTabLoading[tabIndex]!;

    // 1. First time loading this specific tab
    if (loading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Empty State
    if (list.isEmpty) {
      return const Center(child: Text("No records found"));
    }

    return RefreshIndicator(
      onRefresh: () => fetchTrips(tabIndex: tabIndex, isRefresh: true),
      child: ListView.separated(
        itemCount: list.length + (hasMore[tabIndex]! ? 1 : 0),
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == list.length) {
            // 3. Pagination Loader
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child:
                    loading
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                          onPressed: () => fetchTrips(tabIndex: tabIndex),
                          child: const Text("Load More"),
                        ),
              ),
            );
          }
          return _buildTripCard(list[index], context);
        },
      ),
    );
  }

  // ------------------------
  // Build trip card
  // ------------------------
  Widget _buildTripCard(trip, BuildContext context) {
    final tripId = trip['trip_id'];
    final isExpanded = expandedTripID == tripId;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip['trip_name'] ?? '-',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.teal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 🔹 Column 2: Centered electric car icon
                if (trip['veh_express'] == 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: expressDelivery,
                  ),

                if ((trip['start_km'] == null ||
                        (trip['veh_express'] == 1 && trip['end_km'] == null)) &&
                    viewOnly == 0 &&
                    trip['allowToEdit'] == 1)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TripFormScreen(trip: trip),
                          ),
                        ).then((updated) {
                          if (updated == true)
                            fetchTrips(tabIndex: 0, isRefresh: true);
                        });
                      } else if (value == 'delete') {
                        if ((trip['invoices'] as List).isEmpty) {
                          // ✅ allow delete
                          deleteTrip(trip['trip_id']);
                        } else {
                          // ❌ show popup
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text("Delete Not Allowed"),
                                  content: const Text(
                                    "This trip cannot be deleted because it has invoices assigned.",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("OK"),
                                    ),
                                  ],
                                ),
                          );
                        }
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Row(
                              children: const [
                                Icon(Icons.edit, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          if (!(trip['veh_express'] == 1 &&
                              trip['start_km'] != null))
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: const [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                        ],
                  ),
              ],
            ),
            // Text('start km ${trip['start_km'].toString()}'),
            // Text(trip['veh_express'].toString()),
            // Text(trip['end_km'].toString()),
            TripStatusFlag(startKm: trip['start_km'], endKm: trip['end_km']),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🔹 Column 1: Vehicle, driver, associate driver names
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip["vehicle"]}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                          ),
                        ),
                        Text(
                          '${trip["driver"]}',
                          style: TextStyle(color: primaryTeal),
                        ),
                        Text('${trip["associate_driver_names"]}'),
                        if (trip['start_km'] != null)
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Start KM: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${trip['start_km']}'),
                                if (trip['end_km'] != null) ...[
                                  const TextSpan(
                                    text: ' End KM: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: '${trip['end_km']}'),
                                ],
                              ],
                            ),
                          ),
                        if (trip['start_time'] != null)
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Start Time: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${trip['start_time']}'),
                                if (trip['end_time'] != null) ...[
                                  const TextSpan(
                                    text: ' End Time: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: '${trip['end_time']}'),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if ((trip['invoices'] as List).isNotEmpty)
              _buildInvoicesExpansionTile(
                trip['invoices'] as List,
                trip['veh_express'] as int,
                trip['allowToEdit'] as int,
                isExpanded,
                () {
                  setState(() {
                    expandedTripID = isExpanded ? null : tripId;
                  });
                },
              ),

            if ((trip['invoices'] as List).isEmpty)
              const Text(
                'No invoices for this trip.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------------
  // Build invoice ExpansionTile
  // ------------------------
  Widget _buildInvoicesExpansionTile(
    List invoices,
    int veh_express,
    int allowToEdit,
    bool initiallyExpanded,
    VoidCallback onExpansionChanged,
  ) {
    final allInvoicesDespatched = invoices.every(
      (inv) => inv['invoice_status_int'] >= 6,
    );
    final deliveredCount =
        invoices.where((inv) => inv['invoice_status_int'] == 7).length;

    return ExpansionTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(
        'Invoices (${deliveredCount}/${invoices.length})',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      initiallyExpanded: initiallyExpanded,
      onExpansionChanged: (_) => onExpansionChanged(),
      children:
          invoices
              .map(
                (invoice) => _buildInvoiceItem(
                  invoice,
                  allInvoicesDespatched,
                  veh_express,
                  allowToEdit,
                ),
              )
              .toList(),
    );
  }

  Widget _buildInvoiceItem(
    invoice,
    allInvoicesDespatched,
    int veh_express,
    int allowToEdit,
  ) {
    // Example status color
    /*final cardBGColor = getInvoiceCardBGColor(
      invoiceCurrentStatus: invoice['invoice_status_int'],
      holdStatus: invoice['holdStatus'],
    );*/
    final cardBGColor = getInvoiceCardBGColor(
      invoiceCurrentStatus: (invoice['invoice_status_int'] ?? 0) as int,
      holdStatus: (invoice['holdStatus'] ?? 0) as int,
    );
    final isDisabled = isInvoiceDisabled(
      invoice['invoice_status_int'],
      invoice['holdStatus'],
      'test',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: cardBGColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),

      child: ExpansionTile(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Invoice title
            Expanded(
              child: Text(
                invoice['doc_num'] ?? 'Invoice',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: secondaryTeal,
                ),
              ),
            ),

            // Right: Column with flags under the arrow
            if (invoice['expressFlag']?.toLowerCase() != 'exp')
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(width: 4),
                  buildFlag(
                    invoice['trip_sort'].toString(),
                    Colors.yellow.shade900,
                  ),
                ],
              ),
          ],
        ),

        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // small space from arrow
                buildFlag(
                  invoice['invoice_status']
                      .replaceAll('\\n', '') // 👈 replaces raw \n
                      .replaceAll('\n', '')
                      .toString(),
                  getStatusColor(invoice['invoice_status_int']),
                ),
              ],
            ),
            if (invoice['otherBranchDel'] == 1)
              (invoice['delFromBranchName'] != null &&
                      invoice['delFromBranchName']!.isNotEmpty)
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
                              (invoice['delFromBranchName'] as String?)
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
            Text(
              (invoice['customer_name'] as String?)?.toTitleCase() ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            if (invoice['order_id'] != null &&
                invoice['order_id'].isNotEmpty) ...[
              const SizedBox(height: 4),

              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: "Order ID: ",
                      style: TextStyle(
                        // fontWeight: FontWeight.bold,
                        color: secondaryTeal,
                        fontSize: 14,
                      ),
                    ),
                    TextSpan(
                      text: invoice['order_id'], // your date value here
                      style: TextStyle(color: secondaryTeal, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                // Created At
                const Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: secondaryTeal,
                ),
                const SizedBox(width: 1),
                Text(
                  invoice['docCreatedAt'],
                  style: const TextStyle(
                    fontSize: 14,
                    // fontWeight: FontWeight.bold,
                    color: secondaryTeal,
                  ),
                ),
                const SizedBox(width: 1), // space between the two dates
                // Expected Delivery Time
                if (invoice['expectedDeliveryTime'] != null &&
                    invoice['expectedDeliveryTime'].isNotEmpty) ...[
                  expectedDelivery(size: 18),
                  const SizedBox(width: 1),
                  Text(
                    invoice['expectedDeliveryTime'],
                    style: const TextStyle(
                      fontSize: 12,
                      // fontWeight: FontWeight.bold,
                      color: secondaryTeal,
                    ),
                  ),
                ],
              ],
            ),
            if (invoice['deliveredTime'] != null &&
                invoice['deliveredTime'].isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.done_all, size: 18, color: secondaryTeal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      invoice['deliveredTime'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: secondaryTeal,
                        // fontWeight: FontWeight.bold,
                      ),
                      maxLines: null,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
            if (invoice['delRemarks'] != null &&
                invoice['delRemarks'].isNotEmpty)
              Row(
                children: [
                  const Icon(Icons.message, size: 18, color: secondaryTeal),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      invoice['delRemarks'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: secondaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: null,
                      softWrap: true,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 6),

            Wrap(
              spacing: 0,
              runSpacing: 2.0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (invoice['hard_copy'] == 1) buildFlag('H', Colors.orange),
                if (invoice['hard_copy'] == 1 && invoice['cod_flag'] == 1)
                  const SizedBox(width: 6),
                if (invoice['cod_flag'] == 1) buildFlag('COD', Colors.green),
                if (invoice['sign_only'] == 1) const SizedBox(width: 6),
                if (invoice['sign_only'] == 1)
                  buildFlag('Sign Only', Colors.red),
                if (invoice['expressFlag']?.toLowerCase() == 'exp')
                  expressDelivery,
                HoldCancelInfo(
                  invoiceCurrentStatus: invoice['invoice_status_int'],
                  holdStatus: invoice['holdStatus'],
                  holdAt: invoice['holdAt'],
                  holdReason: invoice['holdReason'],
                  holdReschedule: invoice['holdReschedule'],
                ),
                if (invoice['otherBranchDel'] == 1)
                  otherBranchDelivery(size: 20, color: Colors.purpleAccent),
              ],
            ),
          ],
        ),
        children: [
          Container(
            color: cardBGColor, // background color
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const SizedBox(width: 16),
                    const Text(
                      'Items',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Padding(
                      padding: EdgeInsets.only(
                        right: 16,
                      ), // Move "Loaded" 16px left from the edge
                      child: Text(
                        'Loaded',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                if (invoice['items'] != null &&
                    (invoice['items'] as List).isNotEmpty)
                  Column(
                    children:
                        (invoice['items'] as List<dynamic>)
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
                                      style: TextStyle(color: primaryTeal),
                                    ),
                                  ],
                                ),

                                trailing:
                                    (viewOnly == 1 ||
                                            allowToEdit == 0 ||
                                            invoice['sign_only'] == 1)
                                        ? (item['item_loaded'] == 1
                                            ? const Icon(
                                              Icons.check_circle,
                                              color: Colors.green,
                                            )
                                            : const Icon(
                                              Icons.radio_button_unchecked,
                                              color: Colors.grey,
                                            ))
                                        : allInvoicesDespatched ||
                                            veh_express == 1
                                        ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                        : (_loadingItemIds.contains(
                                              item['item_id'],
                                            )
                                            ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : Checkbox(
                                              value: item['item_loaded'] == 1,
                                              onChanged:
                                                  isDisabled
                                                      ? null // 👈 Disable checkbox if true
                                                      : (value) async {
                                                        if (value != null) {
                                                          final previousValue =
                                                              item['item_loaded'];
                                                          setState(() {
                                                            item['item_loaded'] =
                                                                value ? 1 : 0;
                                                            _loadingItemIds.add(
                                                              item['item_id'],
                                                            );
                                                          });

                                                          try {
                                                            // Optimistically update UI

                                                            await updateItemLoadedStatus(
                                                              invoice['invoice_id'],
                                                              item['item_id'],
                                                              value,
                                                              item,
                                                            );
                                                          } catch (e) {
                                                            setState(() {
                                                              item['item_loaded'] =
                                                                  previousValue;
                                                            });
                                                            /*print(
                                                              "Update failed: $e",
                                                            );*/
                                                            ScaffoldMessenger.of(
                                                              context,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  "Failed to update item",
                                                                ),
                                                              ),
                                                            );
                                                          } finally {
                                                            setState(() {
                                                              _loadingItemIds
                                                                  .remove(
                                                                    item['item_id'],
                                                                  );
                                                            });
                                                          }
                                                        }
                                                      },
                                            )),
                              ),
                            )
                            .toList(),
                  ),
                if (invoice['items'] == null ||
                    (invoice['items'] as List).isEmpty)
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

  int tripsCount(String status) {
    return filteredTrips(status).length;
  }

  // ------------------------
  // Main build
  // ------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Remove DefaultTabController
      appBar: Navbar(
        title: "Trips",
        rightOptions: true,
        showFilter: true,
        filterEnabled: showFilters,
        onFilterPressed: () {
          setState(() => showFilters = !showFilters);
        },
      ),

      drawer: ArgonDrawer(currentPage: "Trips"),
      body: Stack(
        children: [
          backgroundAllScreen(),

          // 1. Initial Setup Loader (Checking Prefs/Branches)
          if (!isInitialSetupDone)
            const Center(child: CircularProgressIndicator())
          else
            Column(
              children: [
                FilterSection(
                  showFilters: showFilters,
                  showBranch: true,
                  showDate: true,

                  isMultiBranch: 1,
                  branchesDrop: branchesDrop,
                  selectedBranchId: selectedBranchId,
                  onBranchChanged: (branch) async {
                    selectedBranchId = branch?.id;
                    _resetAllTabData();
                  },

                  startDate: dateRange?.start,
                  endDate: dateRange?.end,
                  onDateRangeChanged: (range) async {
                    dateRange = range;
                    _resetAllTabData();
                  },
                ),

                Material(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: "Preparing (${tabCounts['Preparing']})"),
                      Tab(text: "Dispatched (${tabCounts['Dispatched']})"),
                      Tab(text: "Completed (${tabCounts['Completed']})"),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTripListByStatus(0), // Tab 0: Preparing
                      _buildTripListByStatus(1), // Tab 1: Dispatched
                      _buildTripListByStatus(2), // Tab 2: Completed
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton:
          (viewOnly == 0)
              ? FloatingActionButton(
                child: Icon(Icons.add),
                backgroundColor: secondaryTeal,
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TripFormScreen()),
                  );
                },
              )
              : null,
    );
  }
}
