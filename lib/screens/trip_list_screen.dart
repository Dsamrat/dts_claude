import 'package:dts/utils/string_extensions.dart';
import 'package:dts/widgets/hold_cancel_info.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/common.dart';
import '../models/branch.dart';
import '../screens/trip_form_screen.dart';
import '../services/branch_service.dart';
import '../services/trip_service.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/build_flag.dart';
import '../widgets/drawer.dart';

import '../widgets/trip_status.dart';

import 'package:intl/intl.dart';

class TripListScreen extends StatefulWidget {
  final int? highlightTripID;
  const TripListScreen({super.key, this.highlightTripID});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

// class _TripListScreenState extends State<TripListScreen> {
class _TripListScreenState extends State<TripListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController; // Define the controller
  // ... your other variables (trips, isLoading, etc.)
  List<dynamic> trips = [];
  bool isLoading = true;
  final TripService _tripService = TripService();
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
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  int _getInitialTabIndex() {
    if (widget.highlightTripID == null) return 0; // Default to 'Preparing'

    // Find the trip in your list
    final highlightedTrip = trips.firstWhere(
      (t) => t['trip_id'] == widget.highlightTripID,
      orElse: () => null,
    );

    if (highlightedTrip == null) return 0;

    // Use your existing logic to determine status
    final startKm = highlightedTrip['start_km'];
    final endKm = highlightedTrip['end_km'];
    final bool hasStartKm = startKm != null && startKm != 0;
    final bool hasEndKm = endKm != null && endKm != 0;

    if (!hasStartKm && !hasEndKm) return 0; // Preparing
    if (hasStartKm && !hasEndKm) return 1; // Dispatched
    return 2; // Completed
  }

  Future<void> _init() async {
    await _loadUserDetails();
    await loadInitialData();

    setState(() {
      expandedTripID = widget.highlightTripID;
    });
    // Programmatically move to the correct tab after data is ready
    int index = _getInitialTabIndex();
    _tabController.animateTo(index);
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
      isLoading = true;
    });

    if (currentUserBranchId != null && currentUserId != null) {
      try {
        await fetchTrips(); // ✅ wait for fetchTrips to finish
      } catch (e) {
        // print('Error loading trips: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load trips')));
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> loadInitialData() async {
    branchesDrop = await _branchService.getBranches();
    if (selectedBranchId == null && branchesDrop.isNotEmpty) {
      selectedBranchId = branchesDrop.first.id;
    }
  }

  Future<void> fetchTrips() async {
    try {
      String? start, end;

      if (dateRange != null) {
        start = DateFormat('yyyy-MM-dd').format(dateRange!.start);
        end = DateFormat('yyyy-MM-dd').format(dateRange!.end);
      } else {
        start = null;
        end = null;
      }
      final tripsData = await _tripService.fetchTrips(
        selectedBranchId!,
        currentUserId!,
        start,
        end,
      );

      setState(() {
        trips = tripsData;
        isLoading = false;
      });
    } catch (e) {
      // print('Error fetching trips: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load trips')));
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

      final response = await _tripService.updateItemLoaded(dataToSend);

      setState(() {
        isLoading = false;
      });
      // print(response['tripId']);

      final tripIndex = trips.indexWhere(
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
      }
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
      await _tripService.deleteTrip(tripId);
      fetchTrips();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Trip Deleted')));
    }
  }

  Widget _branchDropdown() {
    return DropdownButtonFormField<int>(
      value: selectedBranchId,
      decoration: InputDecoration(
        labelText: "Select Branch",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items:
          branchesDrop.map((b) {
            return DropdownMenuItem<int>(value: b.id, child: Text(b.name));
          }).toList(),
      onChanged: (value) async {
        selectedBranchId = value;
        await fetchTrips();
      },
    );
  }

  Widget _dateRangeField(BuildContext context) {
    String label;

    if (dateRange == null) {
      label = "Select Date Range";
    } else {
      label =
          "${DateFormat('dd/MM/yyyy').format(dateRange!.start)} → ${DateFormat('dd/MM/yyyy').format(dateRange!.end)}";
    }

    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange:
              dateRange ??
              DateTimeRange(start: DateTime.now(), end: DateTime.now()),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );

        if (picked != null) {
          // print('picked $picked');
          dateRange = picked;
          await fetchTrips();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            if (dateRange != null)
              GestureDetector(
                onTap: () async {
                  dateRange = null;
                  await fetchTrips();
                },
                child: const Icon(Icons.close, color: Colors.red),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.calendar_month),
          ],
        ),
      ),
    );
  }

  Widget _stickyFilters(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          _branchDropdown(),
          const SizedBox(height: 12),
          _dateRangeField(context),
        ],
      ),
    );
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
  Widget _buildTripListByStatus(String status) {
    final tripsForStatus = filteredTrips(status);

    if (tripsForStatus.isEmpty) {
      return const Center(
        child: Text(
          "No records found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchTrips,
      child: ListView.separated(
        padding: const EdgeInsets.all(2),
        itemCount: tripsForStatus.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final trip = tripsForStatus[index];
          return _buildTripCard(trip, context);
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
                          if (updated == true) fetchTrips();
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
    final cardBGColor = getInvoiceCardBGColor(
      invoiceCurrentStatus: invoice['invoice_status_int'],
      holdStatus: invoice['holdStatus'],
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
      appBar: AppBar(
        backgroundColor: secondaryTeal,
        title: Text("Trips"),
        actions: [
          IconButton(
            icon: Icon(
              showFilters ? Icons.filter_alt_off : Icons.filter_alt,
              color: Colors.white, // replace with secondaryTeal
            ),
            tooltip: showFilters ? "Hide Filters" : "Show Filters",
            onPressed: () {
              setState(() {
                showFilters = !showFilters; // toggle icon state
              });
            },
          ),
        ],
      ),
      drawer: ArgonDrawer(currentPage: "Trips"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  if (showFilters) _stickyFilters(context),
                  Material(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController, // <--- Add this
                      labelColor: Colors.teal,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.teal,
                      tabs: [
                        Tab(text: 'Preparing (${tripsCount("Preparing")})'),
                        Tab(text: 'Dispatched (${tripsCount("Dispatched")})'),
                        Tab(text: 'Completed (${tripsCount("Completed")})'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController, // <--- Add this
                      children: [
                        _buildTripListByStatus("Preparing"),
                        _buildTripListByStatus("Dispatched"),
                        _buildTripListByStatus("Completed"),
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

  Widget buildOld(BuildContext context) {
    return DefaultTabController(
      length: 3,
      // initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text("Trips"),
          actions: [
            IconButton(
              icon: Icon(
                showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                color: Colors.white, // replace with secondaryTeal
              ),
              tooltip: showFilters ? "Hide Filters" : "Show Filters",
              onPressed: () {
                setState(() {
                  showFilters = !showFilters; // toggle icon state
                });
              },
            ),
          ],
        ),
        // appBar: Navbar(title: "Trips"),
        drawer: ArgonDrawer(currentPage: "Trips"),
        body: Stack(
          children: [
            backgroundAllScreen(),

            isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    // ✅ Sticky Filters (only when true)
                    if (showFilters) _stickyFilters(context),

                    // ✅ TabBar with counts
                    Material(
                      color: Colors.white,
                      child: TabBar(
                        labelColor: Colors.teal,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.teal,
                        tabs: [
                          Tab(text: 'Preparing (${tripsCount("Preparing")})'),
                          Tab(text: 'Dispatched (${tripsCount("Dispatched")})'),
                          Tab(text: 'Completed (${tripsCount("Completed")})'),
                        ],
                      ),
                    ),

                    // ✅ TabBarView
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildTripListByStatus("Preparing"),
                          _buildTripListByStatus("Dispatched"),
                          _buildTripListByStatus("Completed"),
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
      ),
    );
  }
}
