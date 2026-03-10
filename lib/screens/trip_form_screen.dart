import 'package:dts/screens/trip_list_screen.dart';
import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Assuming these service files exist in the '../services/' directory
import '../constants/common.dart';
import '../services/trip_service.dart';

import '../widgets/background_allscreen.dart';
import '../widgets/build_flag.dart';
import '../widgets/hold_cancel_info.dart';
import '../widgets/navbar.dart';

class TripFormScreen extends StatefulWidget {
  final Map<String, dynamic>? trip; // For edit

  TripFormScreen({super.key, this.trip});

  @override
  State<TripFormScreen> createState() => _TripFormScreenState();
}

class _TripFormScreenState extends State<TripFormScreen> {
  List<dynamic> _assignedVehicles = [];
  Map<String, dynamic>?
  _selectedVehicle; // This will still hold the full map for display
  int? _selectedVehicleId; // NEW: To hold the ID for DropdownButton comparison
  List<dynamic> _drivers = [];
  Map<String, dynamic>? _selectedDriver;

  List<dynamic> _associateDrivers = [];
  List<Map<String, dynamic>> _selectedAssociateDrivers = [];

  List<dynamic> _pickedInvoices = [];
  List<dynamic> _allInvoices = [];
  List<Map<String, dynamic>> _selectedInvoices = [];

  final TripService _tripService = TripService();

  int? currentUserBranchId;
  int? currentUserId;
  int? _tripId;
  bool _isLoading = true;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Load user info
      final prefs = await SharedPreferences.getInstance();
      currentUserBranchId = prefs.getInt('branchId');
      currentUserId = prefs.getInt('userId');
      _tripId = widget.trip?['trip_id'];

      if (currentUserBranchId == null) {
        debugPrint("⚠️ currentUserBranchId is null — skipping data fetch");
        return;
      }

      // Fetch all data in parallel
      await Future.wait([
        _fetchAssignedVehicles(),
        _fetchDrivers(),
        _fetchDeliverySupport(),
        _fetchAllInvoices(),
      ]);

      // Populate form fields after fetching data
      if (widget.trip != null) {
        _populateFields();
      }
    } catch (e, st) {
      debugPrint('❌ Error during initial data load: $e');
      debugPrint(st.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load initial data. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loading indicator
        });
      }
    }
  }

  Future<void> _populateFields() async {
    final trip = widget.trip;
    if (trip != null) {
      // Removed empty checks as data should be fetched by now
      // Pre-select the vehicle
      final vehicleId = trip['vehicle_id'];
      _selectedVehicleId = vehicleId; // Set the ID here

      // Find the actual vehicle map object from the newly fetched list
      _selectedVehicle = _assignedVehicles.firstWhere(
        (v) => v['as_vehicle_id'] == vehicleId,
        orElse: () => null,
      );

      // Pre-select the driver (only if _selectedVehicle is found to get as_driver_id)
      if (_selectedVehicle != null) {
        final driverId =
            _selectedVehicle!['as_driver_id']; // Use driver from selected vehicle
        _selectedDriver = _drivers.firstWhere(
          (d) => d['id'] == driverId,
          orElse: () => null,
        );
      } else {
        _selectedDriver = null; // Clear if no vehicle selected
      }

      // Pre-select associate drivers (based on the original trip data or selected vehicle)
      // Prioritize the actual trip's associate_driver_ids if editing, otherwise from selected vehicle
      List<int> associateDriverIds = [];
      if (trip['associate_driver_ids'] != null) {
        associateDriverIds = List<int>.from(trip['associate_driver_ids']);
      } else if (_selectedVehicle != null &&
          _selectedVehicle!['as_associate_driver'] is List) {
        associateDriverIds = List<int>.from(
          _selectedVehicle!['as_associate_driver'],
        );
      }

      _selectedAssociateDrivers =
          _associateDrivers
              .where((d) => associateDriverIds.contains(d['id']))
              .map((d) => d as Map<String, dynamic>)
              .toList();

      // Pre-select and order invoices
      final selectedInvoiceIds = List<int>.from(trip['invoice_ids'] ?? []);
      final Map<int, dynamic> availableInvoicesMap = {
        for (var invoice in _pickedInvoices)
          invoice['ptm_p_invoice_id']: invoice,
      };

      // Filter and then sort by the original order from selectedInvoiceIds
      _selectedInvoices =
          selectedInvoiceIds
              .where((id) => availableInvoicesMap.containsKey(id))
              .map((id) => availableInvoicesMap[id] as Map<String, dynamic>)
              .toList();

      // No need for setState here, as _loadInitialData will call setState((){_isLoading=false})
    }
  }

  Future<void> _fetchAssignedVehicles() async {
    if (currentUserBranchId == null) return;
    try {
      final vehicles = await _tripService.fetchAssignedVehicles(
        currentUserBranchId!,
        widget.trip?['trip_id'],
      );
      // No setState here, wait for _loadInitialData to call it
      _assignedVehicles = vehicles;
    } catch (e) {
      // print('Error fetching vehicles: $e');
      // SnackBar handled by parent _loadInitialData catch block now or if a specific error needs to be shown
      rethrow; // Re-throw to be caught by Future.wait in _loadInitialData
    }
  }

  Future<void> _fetchDrivers() async {
    if (currentUserBranchId == null) return;
    try {
      final driversData = await _tripService.fetchDrivers(
        currentUserBranchId!,
        _tripId,
      );
      // No setState here
      _drivers = driversData;
    } catch (e) {
      // print('Error fetching drivers: $e');
      rethrow;
    }
  }

  Future<void> _fetchDeliverySupport() async {
    if (currentUserBranchId == null) return;
    try {
      final deliverySupportData = await _tripService.fetchDeliverySupport(
        currentUserBranchId!,
        _tripId,
      );
      // No setState here
      _associateDrivers = deliverySupportData;
    } catch (e) {
      // print('Error fetching drivers: $e');
      rethrow;
    }
  }

  Future<void> _fetchAllInvoices() async {
    if (currentUserBranchId == null) return;
    try {
      final invoicesData = await _tripService.fetchPickedInvoices(
        currentUserBranchId,
        _tripId,
      );
      // No setState here
      _allInvoices = invoicesData;
      // Initially show all
      setState(() {
        _pickedInvoices = List.from(_allInvoices);
      });
    } catch (e) {
      // print('Error fetching invoices: $e');
      rethrow;
    }
  }

  void _onVehicleSelected(int? vehicleId) {
    // Changed type to int?
    setState(() {
      _selectedVehicleId = vehicleId; // Update the ID

      // Find the corresponding full vehicle map from the current _assignedVehicles list
      _selectedVehicle = _assignedVehicles.firstWhere(
        (v) => v['as_vehicle_id'] == vehicleId,
        orElse: () => null,
      );

      // Update driver and associate drivers based on the newly selected vehicle
      if (_selectedVehicle != null) {
        _selectedDriver = _drivers.firstWhere(
          (d) => d['id'] == _selectedVehicle!['as_driver_id'],
          orElse: () => null,
        );
        _selectedAssociateDrivers =
            _associateDrivers
                .where(
                  (d) =>
                      (_selectedVehicle!['as_associate_driver'] as List?)
                          ?.contains(d['id']) ??
                      false,
                )
                .map((d) => d as Map<String, dynamic>)
                .toList();
        // ✅ Filter invoices based on vehicle express flag
        final bool isExpressVehicle =
            _selectedVehicle!['veh_express'] == 1; // check express flag
        _pickedInvoices =
            _allInvoices.where((inv) {
              final flag =
                  (inv['invoice_head']?['expressFlag']?.toString() ?? '')
                      .trim()
                      .toLowerCase();
              // print(flag);
              if (isExpressVehicle) {
                return flag == 'exp' || flag == 'exp&';
              } else {
                return flag == 'exp&' || flag == '';
              }
            }).toList();
        _selectedInvoices = [];
      } else {
        // If no vehicle is selected (e.g., dropdown cleared), clear related fields
        _selectedDriver = null;
        _selectedAssociateDrivers = [];
        _pickedInvoices = _pickedInvoices; // show all again
      }
    });
  }

  void _toggleInvoiceSelection(dynamic invoice, bool selected) {
    setState(() {
      if (selected) {
        // Ensure we don't add duplicates
        if (!_selectedInvoices.any(
          (inv) => inv['ptm_p_invoice_id'] == invoice['ptm_p_invoice_id'],
        )) {
          _selectedInvoices.add(invoice as Map<String, dynamic>);
        }
      } else {
        _selectedInvoices.removeWhere(
          (inv) => inv['ptm_p_invoice_id'] == invoice['ptm_p_invoice_id'],
        );
      }
    });
  }

  Future<void> _removeSelectedInvoice(dynamic invoice) async {
    final head = invoice['invoice_head'] ?? {};

    // Special case: 5 or 8 and not express
    if (((head['invoice_status_int'] == 5 && head['sign_only'] == 0) ||
            head['invoice_status_int'] == 8) &&
        head['expressFlag'] != 'exp') {
      final result = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text("Confirmation"),
              //content: const Text("Is the invoice offloaded?"),
              content: RichText(
                text: TextSpan(
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  children: [
                    const TextSpan(
                      style: TextStyle(color: Colors.black, fontSize: 18),
                      text: "Is the invoice offloaded?\n\n",
                    ),
                    const TextSpan(
                      text: "Note:",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const TextSpan(
                      text:
                          " If you confirm, invoice will be removed from the trip",
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text("No"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text("Yes"),
                ),
              ],
            ),
      );

      if (result == true) {
        // ✅ Yes → mark locally as offloaded
        setState(() {
          invoice['offloaded'] = true; // mark for API later
          _selectedInvoices.removeWhere(
            (inv) => inv['ptm_p_invoice_id'] == invoice['ptm_p_invoice_id'],
          );
        });
      } else if (result == false) {
        // ❌ No → alert and stop
        await showDialog(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text("Alert"),
                content: const Text(
                  "Invoice cannot be removed as it is in loaded status",
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text("OK"),
                  ),
                ],
              ),
        );
      }
      return;
    }

    // Normal flow
    setState(() {
      _selectedInvoices.removeWhere(
        (inv) => inv['ptm_p_invoice_id'] == invoice['ptm_p_invoice_id'],
      );
    });
  }

  void _onReorderInvoices(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = _selectedInvoices.removeAt(oldIndex);
      _selectedInvoices.insert(newIndex, item);
    });
  }

  Future<void> _submitForm() async {
    setState(() => isSubmitting = true);

    if (_selectedVehicle == null) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
      return;
    }
    final vehicleId = _selectedVehicle!['as_vehicle_id'];
    final vehicleRegNum = _selectedVehicle!['vehicle_number_plate'];
    final driverId = _selectedDriver?['id'];

    final associateDriverIds =
        _selectedAssociateDrivers.map((d) => d['id']).toList();

    // Normal invoice IDs
    final selectedInvoiceIds =
        _selectedInvoices.map((inv) => inv['ptm_p_invoice_id']).toList();
    final expressVehicle = _selectedVehicle!['veh_express'];
    // print('isExpressVehicle $expressVehicle');
    // print('selectedInvoiceIds isEmpty ${selectedInvoiceIds.isEmpty}');
    if (selectedInvoiceIds.isEmpty && expressVehicle == 0) {
      setState(() => isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one invoice to continue'),
        ),
      );
      return;
    }

    // Offloaded invoices (previously removed with flag)
    final offloadedInvoices =
        _allInvoices
            .where((inv) => inv['offloaded'] == true)
            .map((inv) => inv['ptm_p_invoice_id'])
            .toList();

    final dataToSend = {
      'vehicle_id': vehicleId,
      'vehicleRegNum': vehicleRegNum,
      'driver_id': driverId,
      'associate_driver_ids': associateDriverIds,
      'invoice_ids': selectedInvoiceIds,
      'offloaded_invoice_ids': offloadedInvoices, // 👈 added field
      'currentUserBranchId': currentUserBranchId,
      'trip_id': _tripId,
      'currentUserId': currentUserId,
    };

    try {
      final response = await _tripService.createTrip(dataToSend);
      if (response && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip ${_tripId != null ? 'updated' : 'created'} successfully!',
            ),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => TripListScreen()),
        );
      }
    } catch (e) {
      print('Error submitting trip: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(
        title: _tripId == null ? "Create Trip" : "Edit Trip",
        backButton: true,
      ),
      body: Stack(
        children: [
          backgroundAllScreen(),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadInitialData, // Your async refresh function
                child: SingleChildScrollView(
                  // Important for RefreshIndicator to always work, even if content is short
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. AssignedVehicle Selection
                      DropdownButtonFormField<int>(
                        // Change type to int
                        decoration: InputDecoration(
                          labelText: 'Select Vehicle',
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                            fontSize: 12,
                          ),
                        ),
                        value: _selectedVehicleId, // Use the ID here
                        items:
                            _assignedVehicles
                                .map(
                                  (vehicle) => DropdownMenuItem<int>(
                                    // Change type to int
                                    value:
                                        vehicle['as_vehicle_id']
                                            as int?, // Use the ID here
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: vehicle['vehicle'] ?? 'N/A',
                                          ),
                                          if (vehicle['veh_express'] ==
                                              1) // check for Express flag
                                            const TextSpan(
                                              text: '  Express',
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),

                                    /**/
                                  ),
                                )
                                .toList(),
                        onChanged:
                            _onVehicleSelected, // This now receives an int?
                      ),
                      SizedBox(height: 20),
                      // 2. Driver Display
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Driver',
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                            fontSize: 12,
                          ),
                        ),
                        child: Text(
                          _selectedDriver?['name'] ?? 'N/A',
                          style: TextStyle(color: secondaryTeal),
                        ),
                      ),
                      SizedBox(height: 10),

                      // 3. Delivery Support Display
                      InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Delivery Support',
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                            fontSize: 12,
                          ),
                        ),
                        child: Text(
                          _selectedAssociateDrivers
                              .map((d) => d['name'] as String? ?? 'N/A')
                              .join(', '),
                          style: TextStyle(color: secondaryTeal),
                        ),
                      ),
                      SizedBox(height: 20),

                      // 3. Invoice Selection
                      Text(
                        'Select Invoices:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        height: 350,
                        child: ListView.builder(
                          /*shrinkWrap: true,
                          physics:
                              NeverScrollableScrollPhysics(),*/
                          // Keep this for nested ListView
                          physics: const BouncingScrollPhysics(),
                          itemCount: _pickedInvoices.length,
                          itemBuilder: (context, index) {
                            final invoice = _pickedInvoices[index];
                            final invoiceHead = invoice['invoice_head'] ?? {};
                            // Check if the current invoice from _pickedInvoices is in _selectedInvoices
                            final bool isSelected = _selectedInvoices.any(
                              (selectedInv) =>
                                  selectedInv['ptm_p_invoice_id'] ==
                                  invoice['ptm_p_invoice_id'],
                            );

                            final cardBGColor = getInvoiceCardBGColor(
                              invoiceCurrentStatus:
                                  invoiceHead['invoice_status_int'],
                              holdStatus: invoiceHead['holdStatus'],
                            );
                            final isDisabled = isInvoiceDisabled(
                              invoiceHead['invoice_status_int'],
                              invoiceHead['holdStatus'],
                              'test',
                            );

                            return (isSelected)
                                ? const SizedBox.shrink() // hide completely
                                : Card(
                                  color: cardBGColor,
                                  child: CheckboxListTile(
                                    value: isSelected, // Use the proper check
                                    onChanged:
                                        isDisabled || isSelected
                                            ? null // 👈 Disable checkbox
                                            : (bool? value) =>
                                                _toggleInvoiceSelection(
                                                  invoice,
                                                  value ?? false,
                                                ),
                                    title: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Always show doc_num
                                        Text(
                                          '${invoiceHead['doc_num'] ?? 'N/A'}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),

                                        // Show "Delivery From <branch>" only if otherBranchDel == 1 and delFromBranchName is not null/empty
                                        if (invoiceHead['otherBranchDel'] ==
                                                1 &&
                                            invoiceHead['delFromBranchName'] !=
                                                null &&
                                            (invoiceHead['delFromBranchName']
                                                    as String)
                                                .isNotEmpty)
                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.black87,
                                              ),
                                              children: [
                                                const TextSpan(
                                                  text: 'Delivery From ',
                                                ), // regular
                                                TextSpan(
                                                  text:
                                                      (invoiceHead['delFromBranchName']
                                                              as String)
                                                          .capitalize(),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),

                                    subtitle: Wrap(
                                      spacing: 4.0,
                                      runSpacing: 4.0,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,

                                      children: [
                                        if (invoiceHead['customer_name'] !=
                                            null)
                                          Text(
                                            (invoiceHead['customer_name']
                                                        as String?)
                                                    ?.toTitleCase() ??
                                                '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        const SizedBox(width: double.infinity),
                                        if (invoiceHead['expressFlag']
                                                ?.toLowerCase() ==
                                            'exp')
                                          expressDelivery,
                                        invoiceHead['sign_only'] == 1
                                            ? const SizedBox.shrink()
                                            : buildFlag(
                                              invoiceHead['invoice_status']
                                                  .replaceAll(
                                                    '\\n',
                                                    '',
                                                  ) // 👈 replaces raw \n
                                                  .replaceAll('\n', '')
                                                  .toString(),
                                              Colors.grey,
                                            ),
                                        if (invoiceHead['sign_only'] == 1)
                                          buildFlag('sign Only', Colors.red),
                                        HoldCancelInfo(
                                          invoiceCurrentStatus:
                                              invoiceHead['invoice_status_int'],
                                          holdStatus: invoiceHead['holdStatus'],
                                          holdAt: invoiceHead['holdAt'],
                                          holdReason: invoiceHead['holdReason'],
                                          holdReschedule:
                                              invoiceHead['holdReschedule'],
                                        ),
                                      ],
                                    ),
                                    // Removed the remove button from CheckboxListTile, it's confusing with selection
                                    // If you want a remove button, it should be external or in the reorderable list
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                );
                          },
                        ),
                      ),
                      SizedBox(height: 20),

                      // 4. Sortable Invoices
                      if (_selectedInvoices.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Order Selected Invoices:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 10),
                            SizedBox(
                              height: 300,
                              child: ReorderableListView.builder(
                                /*shrinkWrap: true,
                                physics:
                                    NeverScrollableScrollPhysics(), */
                                // Keep this for nested ListView
                                physics: const BouncingScrollPhysics(),
                                itemCount: _selectedInvoices.length,
                                itemBuilder: (context, index) {
                                  final invoice = _selectedInvoices[index];
                                  final invoiceHead =
                                      invoice['invoice_head'] ?? {};
                                  final selCardBGColor =
                                      (invoiceHead['inv_canceled'] == 1 ||
                                              invoiceHead['inv_onhold'] == 1)
                                          ? Colors.red.shade100
                                          : Colors.white;

                                  return Card(
                                    color: selCardBGColor,
                                    key: ValueKey(invoice['ptm_p_invoice_id']),
                                    child: ListTile(
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Always show doc_num
                                          Text(
                                            '${invoiceHead['doc_num'] ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),

                                          // Show "Delivery From <branch>" only if otherBranchDel == 1 and delFromBranchName is not null/empty
                                          if (invoiceHead['otherBranchDel'] ==
                                                  1 &&
                                              invoiceHead['delFromBranchName'] !=
                                                  null &&
                                              (invoiceHead['delFromBranchName']
                                                      as String)
                                                  .isNotEmpty)
                                            RichText(
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.black87,
                                                ),
                                                children: [
                                                  const TextSpan(
                                                    text: 'Delivery From ',
                                                  ), // regular
                                                  TextSpan(
                                                    text:
                                                        (invoiceHead['delFromBranchName']
                                                                as String)
                                                            .capitalize(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      ),

                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${invoiceHead['customer_name'] ?? 'N/A'}',
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        // Added remove button here for clarity
                                        icon: Icon(
                                          Icons.remove_circle_outline,
                                          color: Colors.red,
                                        ),
                                        onPressed:
                                            () =>
                                                _removeSelectedInvoice(invoice),
                                      ),
                                    ),
                                  );
                                },
                                onReorder: _onReorderInvoices,
                              ),
                            ),
                            SizedBox(height: 30),
                          ],
                        ),

                      // 6. Submit Button
                      ElevatedButton(
                        onPressed: isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                        ),
                        child:
                            isSubmitting
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
