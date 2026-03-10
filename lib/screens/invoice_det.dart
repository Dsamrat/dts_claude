import 'package:dts/constants/common.dart';
import 'package:dts/models/invoice.dart';
import 'package:dts/utils/string_extensions.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

// LOAD WIDGETS
import 'package:dts/widgets/navbar.dart';
import 'package:dts/widgets/drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// LOAD SERVICES
import '../models/branch.dart';
import '../models/pickup_team_model.dart';
import '../models/sales_person.dart';
import '../services/branch_service.dart';
import '../services/invoice_service.dart';
import '../utils/dialogs.dart';
import '../widgets/action_modal_form.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/button.dart';
import 'package:dts/screens/build_invoice_timeline.dart';

import '../widgets/custom_dropdown.dart';
import 'courier_popup.dart';
import 'home_screen.dart';
import 'package:intl/intl.dart';

class InvoiceDet extends StatefulWidget {
  final Invoice? invoice;
  const InvoiceDet({super.key, this.invoice});

  @override
  State<InvoiceDet> createState() => _InvoiceDetState();
}

class _InvoiceDetState extends State<InvoiceDet> {
  int? invoiceHead;
  int? departmentId;
  int invoiceCurrentStatus = 1;
  int? currentUserId;
  String? currentUserName;
  int? userBranchId;
  List<int> selectedPickupPersonIds = [];
  String? buttonText = 'Save';
  List<dynamic> itemDetails = [];
  List<dynamic> itemStatus = [];
  List<PickupTeamModel> pickupPersons = [];
  List<Branch> branchesDrop = [];

  int? selectedBranchId;
  int? initialBranchId; // 👈 to compare later
  Map<int, bool> signUpdating = {};
  bool isTogglingSignOnly = false;
  final InvoiceService _invoiceService = InvoiceService();
  final BranchService _branchService = BranchService();
  bool loading = false;
  bool loadFailed = false;
  String? _selectedDeliveryType; // for radio
  bool _isSubmitting = false; // loading indicator
  bool isProcessing = false;
  bool get showCollectionPrompt {
    final invoice = widget.invoice!;
    return invoice.salesType == 'Cash Counter' &&
        invoice.soId == 0 &&
        invoice.deliveryType == null &&
        widget.invoice!.codFlag == 0;
  }

  /*COURIER FUNCTION*/
  late Invoice _invoice;
  bool _isLoading = false;
  bool redirectStatus = false;
  /*COURIER FUNCTION*/
  /* ───────────────── Helper functions ───────────────── */

  /*bool _canShowSalespersonOption() {
    const allowedStatuses = [4];
    return allowedStatuses.contains(widget.invoice!.invoiceCurrentStatus);
  }*/
  bool _canShowSalespersonOption() {
    if (widget.invoice == null) return false;

    final status = widget.invoice!.invoiceCurrentStatus;
    final delivery = widget.invoice!.deliveryType;
    if (status == 3 &&
        (delivery == 'Customer Collection' || delivery == 'Courier')) {
      redirectStatus = true;
    }
    return status == 4 ||
        (status == 3 &&
            (delivery == 'Customer Collection' || delivery == 'Courier'));
  }

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice!;
    invoiceHead = widget.invoice!.id;
    _loadData(); // Call the unified data loading method
    debugPrint(DateTime.tryParse(widget.invoice!.holdReschedule) as String?);
  }

  Future<bool> _showTripConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Confirm'),
                content: const Text(
                  'This invoice is already assigned to a trip. Do you want to continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Yes'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  Future<void> _submitUpdates(Map<String, dynamic> data) async {
    setState(() => _isLoading = true);

    try {
      await _invoiceService.updateCourierInfo(
        invoiceId: invoiceHead!.toInt(),
        awbNumber: data['awbNumber'],
        cost: data['courierCost'],
        remarks: data['courierRemarks'],
        currentUserId: currentUserId!.toInt(),
      );

      // Update local invoice object
      setState(() {
        _invoice.awbNumber = data['awbNumber'];
        _invoice.courierCost = data['courierCost'];
        _invoice.courierRemarks = data['courierRemarks'];
        _invoice.courierUpdatedTime = DateFormat(
          "dd/MM/yyyy hh:mm a",
        ).format(DateTime.now());
        _invoice.courierUpdatedBy = currentUserName;
      });

      // ⭐ Show snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Courier details updated successfully!"),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to update courier info"),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadData() async {
    // branchesDrop = await _branchService.getBranches();
    branchesDrop =
        (await _branchService.getBranches())
            .where((branch) => branch.id != null)
            .toList();

    // Determine which branch should be selected initially
    if (widget.invoice!.otherBranchDelivery == 1) {
      selectedBranchId = widget.invoice!.deliveryFromBranchId;
    } else {
      selectedBranchId = widget.invoice!.branchId;
    }

    // Store this value for comparison
    initialBranchId = selectedBranchId;
    await loadUserDetails(); // Load user details first
    await fetchInvoiceDetails(); // Then fetch invoice details
    await fetchInvoiceStatus(); // And then invoice status
  }

  Future<void> fetchInvoiceDetails() async {
    setState(() {
      // Set loading state only once at the beginning
      loading = true;
      loadFailed = false;
    });

    try {
      final response = await _invoiceService.getInvoiceDetails(
        invoiceId: invoiceHead!.toInt(),
      );

      // Process the response data *before* calling setState
      List<dynamic> fetchedItemDetails =
          response['items'] as List<dynamic> ?? [];
      List<int> fetchedPickupPersonIds;
      String fetchedButtonText;
      int fetchedInvoiceCurrentStatus = response['invoice_status'].toInt();

      if (response['invoice_pickup_team'] != null &&
          response['invoice_pickup_team']['pickup_person_ids'] != null) {
        fetchedPickupPersonIds =
            (response['invoice_pickup_team']['pickup_person_ids']
                    as List<dynamic>)
                .whereType<int>()
                .toList();
        fetchedButtonText = 'Update';
      } else {
        fetchedPickupPersonIds = [];
        fetchedButtonText = 'Save';
      }

      // Fetch pickup teams *before* setting state that depends on it.
      // Ensure branchId is not null before calling
      if (userBranchId != null) {
        await fetchPickupTeams(userBranchId: userBranchId!);
      } else {
        if (kDebugMode) {
          print('Warning: branchId is null, cannot fetch pickup teams.');
        }
      }

      // *Now*, call setState once, with all the data.
      setState(() {
        itemDetails = fetchedItemDetails;
        selectedPickupPersonIds = fetchedPickupPersonIds;
        buttonText = fetchedButtonText;
        invoiceCurrentStatus = fetchedInvoiceCurrentStatus;
      });

      if (kDebugMode) {
        print('invoiceCurrentStatus : $invoiceCurrentStatus');
      }
    } catch (e) {
      // Handle errors *before* setting state.
      loadFailed = true;
      if (kDebugMode) {
        print('Error fetching invoice details: $e');
      }
      if (context.mounted) {
        await showErrorDialog(context, 'Failed to load invoice details: $e');
      }
    } finally {
      //  Ensure loading is set to false *always*
      setState(() => loading = false);
    }
  }

  Future<void> fetchPickupTeams({required int userBranchId}) async {
    try {
      final response = await _invoiceService.getPickupTeams(userBranchId);
      setState(() {
        pickupPersons = response;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching pickup teams: $e');
      }
      if (context.mounted) {
        // Decide if you want to show an error for pickup teams separately
        await showErrorDialog(context, 'Failed to load pickup teams: $e');
      }
    }
  }

  Future<void> assignToPicking() async {
    try {
      setState(() {
        // Set loading state only once at the beginning
        loading = true;
        loadFailed = false;
      });
      if (selectedPickupPersonIds.isNotEmpty) {
        await _invoiceService.assignPickupTeam(
          invoiceId: invoiceHead!.toInt(),
          currentUserId: currentUserId!.toInt(),
          pkTeamId:
              pickupPersons.isNotEmpty
                  ? pickupPersons
                      .first
                      .pkId! // Assuming all selected persons belong to the same team. Adjust if needed.
                  : 0,
          // Or handle this case differently
          pickupPersons:
              selectedPickupPersonIds.map((id) => id.toString()).toList(),
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pickup team assigned successfully')),
          );
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least one pickup team member'),
            ),
          );
        }
      }
    } catch (e) {
      loadFailed = true;
      String errorMessage;

      if (e is FormatException) {
        errorMessage = 'Received an invalid response from the server.';
      } else {
        errorMessage =
            e.toString().trim().isEmpty
                ? 'Something went wrong. Please try again.'
                : e.toString();
      }

      if (context.mounted) {
        await showErrorDialog(context, errorMessage);
      }
      if (kDebugMode) {
        print('➡️ catch error: $e');
      }
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _submitDeliveryTypeUpdate() async {
    if (_selectedDeliveryType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a delivery type")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    bool success = await _invoiceService.updateDeliveryType(
      invoiceId: widget.invoice!.id,
      deliveryType: _selectedDeliveryType!,
    );

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Updated successfully")));
      setState(() {
        widget.invoice!.deliveryType = _selectedDeliveryType;
      });
      debugPrint('reached success page');
      // await loadUserDetails(); // Load user details first
      await fetchInvoiceDetails(); // Then fetch invoice details
      await fetchInvoiceStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update delivery type")),
      );
    }
  }

  Future<void> assignToReadyForLoading() async {
    if (kDebugMode) print("Invoice: $invoiceHead");

    setState(() {
      loading = true;
      loadFailed = false;
    });

    try {
      // ⏳ Keep await here (required)
      await _invoiceService.assignToReadyForLoading(
        invoiceId: invoiceHead!.toInt(),
        currentUserId: currentUserId!.toInt(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice status updated to Ready for Loading!'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      loadFailed = true;

      final errorMessage =
          (e is FormatException)
              ? 'Received an invalid response from the server.'
              : (e.toString().trim().isEmpty
                  ? 'Something went wrong. Try again.'
                  : e.toString());

      if (mounted) {
        await showErrorDialog(context, errorMessage);
      }

      if (kDebugMode) print('➡️ catch error: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> completeInvoice() async {
    if (kDebugMode) {
      print(invoiceHead!.toInt());
    }
    try {
      setState(() {
        // Set loading state only once at the beginning
        loading = true;
        loadFailed = false;
      });
      await _invoiceService.completeInvoiceAPI(
        invoiceId: invoiceHead!.toInt(),
        currentUserId: currentUserId!.toInt(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice status updated!')),
        );
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      loadFailed = true;
      String errorMessage;

      if (e is FormatException) {
        errorMessage = 'Received an invalid response from the server.';
      } else {
        errorMessage =
            e.toString().trim().isEmpty
                ? 'Something went wrong. Please try again.'
                : e.toString();
      }

      if (context.mounted) {
        await showErrorDialog(context, errorMessage);
      }
      if (kDebugMode) {
        print('➡️ catch error: $e');
      }
    } finally {
      //  Ensure loading is set to false *always*
      setState(() => loading = false);
    }
  }

  Future<void> fetchInvoiceStatus() async {
    try {
      final response = await _invoiceService.getInvoiceStatus(
        invoiceId: invoiceHead!.toInt(),
      );
      setState(() {
        itemStatus = response;
        if (kDebugMode) {
          print("Fetched itemStatus: $itemStatus");
          print("itemStatus length: ${itemStatus.length}");
        }
      });
    } catch (e) {
      // Handle the error appropriately, e.g., show an error message
      if (kDebugMode) {
        print('Error fetching invoice status: $e');
      }
      if (context.mounted) {
        await showErrorDialog(context, 'Failed to load invoice status: $e');
      }
    }
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    departmentId = prefs.getInt('departmentId');
    currentUserId = prefs.getInt('userId');
    currentUserName = prefs.getString('userName');
    userBranchId = prefs.getInt('branchId');
    if (kDebugMode) {
      print('Reached loadUserDetails - $departmentId');
    }
  }

  IconData _getStatusIcon() {
    if (widget.invoice!.invoiceCurrentStatus == 8) {
      return Icons.cancel; // Cancel icon
    } else if (widget.invoice!.holdStatus == 9) {
      return Icons.lock; // Hold icon
    } else if (widget.invoice!.holdStatus == 10) {
      return Icons.history; // Reschedule icon
    } else {
      return Icons.no_encryption; // Default open lock
    }
  }

  IconData _getDeliveryTypeIcon() {
    if (widget.invoice!.deliveryType == 'Customer Collection') {
      return Icons.directions_walk; // Cancel icon
    } else if (widget.invoice!.deliveryType == 'Courier') {
      return Icons.local_shipping; // Hold icon
    } else if (widget.invoice!.deliveryType == 'Delivery by Salesperson') {
      return Icons.person;
    } else {
      return Icons.fire_truck; // Default open lock
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

  void _openStatusPopup() {
    String initialAction = getInitialAction(
      invoiceCurrentStatus: widget.invoice!.invoiceCurrentStatus,
      holdStatus: widget.invoice!.holdStatus,
    );

    showDialog(
      context: context,
      builder:
          (_) => ActionModalForm(
            initialActionType: initialAction,
            initialReason: widget.invoice!.holdReason,
            initialDateTime:
                widget.invoice!.holdReschedule != null
                    ? DateTime.tryParse(widget.invoice!.holdReschedule)
                    : null,
            invoiceCurrentStatus: widget.invoice!.invoiceCurrentStatus,
            expressFlag: widget.invoice!.expressFlag,
            onSubmit: (action, reason, dateTime, confirmed) async {
              // --------------------------------------------------
              // 1. SAVE OLD STATE (for rollback if API fails)
              // --------------------------------------------------
              final oldInvoiceStatus = widget.invoice!.invoiceCurrentStatus;
              final oldHoldStatus = widget.invoice!.holdStatus;
              final oldHoldReason = widget.invoice!.holdReason;
              // --------------------------------------------------
              // 2. INSTANT UI UPDATE (Optimistic Update)
              // --------------------------------------------------
              setState(() {
                if (action == "Cancel") {
                  widget.invoice!.invoiceCurrentStatus = 8;
                  widget.invoice!.invoiceStatus = 'Canceled';
                  widget.invoice!.holdStatus = 0;
                  widget.invoice!.holdReason = reason.toString();
                } else if (action == "Hold") {
                  widget.invoice!.holdStatus = 9;
                  widget.invoice!.holdReason = reason.toString();
                } else if (action == "Reschedule") {
                  widget.invoice!.holdStatus = 10;
                  widget.invoice!.holdReason = reason.toString();
                } else if (action == "Unhold") {
                  widget.invoice!.holdStatus = 0;
                  widget.invoice!.holdReason = '';
                }
              });

              // show progress indicator (non-blocking)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Updating status... Please wait')),
              );

              // --------------------------------------------------
              // 3. CALL API IN BACKGROUND
              // --------------------------------------------------
              try {
                // bool success = false;

                bool success = await _invoiceService.toggleInvoiceStatus(
                  action,
                  reason,
                  dateTime,
                  confirmed ? 1 : 0,
                  currentUserId!.toInt(),
                  userBranchId!.toInt(),
                  widget.invoice!.id,
                );
                if (!success) {
                  // --------------------------------------------------
                  // 4. ROLLBACK UI IF API FAILED
                  // --------------------------------------------------
                  setState(() {
                    widget.invoice!.invoiceCurrentStatus = oldInvoiceStatus;
                    widget.invoice!.holdStatus = oldHoldStatus;
                    widget.invoice!.holdReason = oldHoldReason;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update status')),
                  );

                  return;
                }
                // --------------------------------------------------
                // 5. API SUCCESS → REFRESH
                // --------------------------------------------------
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Status updated')));

                if (action == "Cancel") {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                } else {
                  await fetchInvoiceStatus(); // Update timeline
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

  void _openDeliveryTypePopup(String? currentType) async {
    final initialSelection = currentType ?? 'Regular';

    List<String> filteredOptions = switch (currentType) {
      null => ['Customer Collection', 'Courier'],
      'Customer Collection' => ['Courier', 'Regular'],
      'Courier' => ['Customer Collection', 'Regular'],
      _ => ['Courier', 'Customer Collection', 'Regular'],
    };

    if (_canShowSalespersonOption()) {
      filteredOptions.add('Delivery by Salesperson');
    }

    filteredOptions = [...filteredOptions, initialSelection];
    final seen = <String>{};
    filteredOptions = [
      for (final opt in filteredOptions)
        if (seen.add(opt)) opt,
    ];

    List<SalesPerson> salesPersons = [];
    SalesPerson? selectedSalesPerson;

    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String tempSelection = initialSelection;
        bool loadingSalespersons = false;

        return AlertDialog(
          title: const Text('Select Delivery Type'),
          content: StatefulBuilder(
            builder: (ctx, setState) {
              Future<void> loadSalesPersons() async {
                if (salesPersons.isNotEmpty || loadingSalespersons) return;

                setState(() => loadingSalespersons = true);
                salesPersons = await _invoiceService.getSalesPersons(
                  userBranchId!,
                );
                debugPrint('Sales Person : ${widget.invoice!.salesPerson}');
                selectedSalesPerson = salesPersons.firstWhere(
                  (e) => e.name == widget.invoice!.salesPerson,
                  orElse: () => salesPersons.first,
                );

                setState(() => loadingSalespersons = false);
              }

              if (tempSelection == 'Delivery by Salesperson') {
                loadSalesPersons();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...filteredOptions.map((opt) {
                    return RadioListTile<String>(
                      title: Text(opt),
                      value: opt,
                      groupValue: tempSelection,
                      onChanged: (val) {
                        setState(() => tempSelection = val!);
                      },
                    );
                  }),

                  if (tempSelection == 'Delivery by Salesperson')
                    loadingSalespersons
                        ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        )
                        : DropdownButtonFormField<SalesPerson>(
                          value: selectedSalesPerson,
                          decoration: const InputDecoration(
                            labelText: 'Select Salesperson',
                          ),
                          items:
                              salesPersons
                                  .map(
                                    (sp) => DropdownMenuItem(
                                      value: sp,
                                      child: Text(sp.name),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) =>
                                  setState(() => selectedSalesPerson = val),
                        ),
                ],
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

    if (selected == null || selected == currentType) return;

    bool confirmFlag = false;

    if (selected == 'Delivery by Salesperson' &&
        widget.invoice!.tripID != null &&
        widget.invoice!.tripID! > 0) {
      confirmFlag = await _showTripConfirmation();
      if (!confirmFlag) return;
    }

    final success = await _invoiceService.toggleDeliveryType(
      selected,
      currentUserId!,
      widget.invoice!.id,
      salesPersonId:
          selected == 'Delivery by Salesperson'
              ? selectedSalesPerson?.id
              : null,
      confirmTripReassign: confirmFlag,
    );
    // debugPrint('success:$success');
    if (success) {
      setState(() {
        widget.invoice!.deliveryType = selected;
        if (selected == 'Delivery by Salesperson') {
          widget.invoice!.salesPerson = selectedSalesPerson?.name;
        }
      });
      // debugPrint('redirectStatus:$redirectStatus');
      if (redirectStatus) {
        await fetchInvoiceDetails();
      }
      await fetchInvoiceStatus();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Status updated')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  void _openBranchPopup(int? preSelectedBranchId, BuildContext safeContext) {
    showDialog(
      context: safeContext,
      builder: (ctx) {
        int? selectedBranchId = preSelectedBranchId;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Select Branch',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomDropdown<Branch>(
                      label: "Select Branch",
                      items: branchesDrop,
                      selectedItem: branchesDrop.firstWhere(
                        (b) => b.id == selectedBranchId,
                        orElse: () => Branch(id: 0, name: 'Select'),
                      ),
                      onChanged: (branch) {
                        if (branch != null) {
                          setState(() {
                            selectedBranchId = branch.id;
                          });
                        }
                      },
                      getLabel: (branch) => branch.name,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Submit'),
              onPressed: () {
                // Null-safe comparison to detect no changes
                if ((selectedBranchId ?? 0) == (preSelectedBranchId ?? 0)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('No changes detected')),
                  );
                  return;
                }

                // 🔹 Build confirmation message based on invoice status
                String message = 'Are you sure you want to continue?';

                // 🔹 Show confirmation dialog
                showDialog(
                  context: safeContext,
                  builder:
                      (confirmCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: const Text(
                          'Confirm Action',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: Text(message),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(confirmCtx),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(confirmCtx); // close confirmation
                              Navigator.pop(ctx); // close branch popup
                              _submitBranch(selectedBranchId); // submit
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Yes, Continue'),
                          ),
                        ],
                      ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(100, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitBranch(int? selectedBranchId) async {
    if (selectedBranchId == null || widget.invoice == null) return;

    debugPrint('selectedBranchId: $selectedBranchId');

    // Expecting a decoded JSON map from your service
    final response = await _invoiceService.toggleBranch(
      selectedBranchId,
      currentUserId!,
      widget.invoice!.id,
    );

    // Example: {"status":"success","result":{"statusChanged":0,...},"message":"Branch updated successfully"}

    debugPrint('$response');

    // Safely access nested values
    final statusChanged = response['result']?['statusChanged'];
    final otherBranchDel = response['result']?['other_branch_del'];
    final delFromBranchId = response['result']?['del_from_branch_id'];
    debugPrint('statusChanged: $statusChanged');

    if (response['status'] == 'success') {
      setState(() {
        // Example of using statusChanged
        debugPrint('✅ Branch status changed: $statusChanged');
        if (statusChanged == 1) {
          widget.invoice!.actionAllowed = 0;
        }
        widget.invoice!.otherBranchDelivery = otherBranchDel;
        widget.invoice!.deliveryFromBranchId = delFromBranchId;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Branch updated successfully'),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconData = _getStatusIcon();
    final deliveryTypeIconData = _getDeliveryTypeIcon();

    final preSelectedBranchId =
        widget.invoice?.otherBranchDelivery == 1
            ? widget.invoice?.deliveryFromBranchId
            : widget.invoice?.branchId;
    return Scaffold(
      appBar: Navbar(
        title: "${widget.invoice!.invoiceNum.toString()} ",
        backButton: true,
      ),
      extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Home"),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : loadFailed
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Failed to load form data."),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                      ),
                      onPressed: _loadData, // Call the refactored method here
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  backgroundAllScreen(),
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // The main Row to hold the left-side Column and the right-side IconButton
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // LEFT SIDE with margin
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if ((widget
                                                  .invoice
                                                  ?.expectedDeliveryTime ??
                                              '')
                                          .isNotEmpty)
                                        Row(
                                          children: [
                                            expectedDelivery(size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              widget
                                                      .invoice
                                                      ?.expectedDeliveryTime ??
                                                  "",
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: secondaryTeal,
                                              ),
                                            ),
                                          ],
                                        ),

                                      const SizedBox(height: 4),
                                      if ((widget.invoice?.delRemarks ?? '')
                                          .isNotEmpty)
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
                                                widget.invoice?.delRemarks ??
                                                    '',
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
                                ),
                              ),

                              // RIGHT SIDE
                              if (widget.invoice?.invoiceCurrentStatus !=
                                      null &&
                                  (widget.invoice!.invoiceCurrentStatus < 7 ||
                                      widget.invoice!.invoiceCurrentStatus ==
                                          11) &&
                                  widget.invoice!.actionAllowed == 1)
                                IconButton(
                                  icon: Icon(
                                    iconData,
                                    color:
                                        (iconData == Icons.no_encryption)
                                            ? Colors.blue
                                            : Colors.red,
                                    size: 32,
                                  ),
                                  onPressed: _openStatusPopup,
                                ),
                              // Show success message only when actionAllowed == 1 and updated
                              if (widget.invoice!.actionAllowed == 1 &&
                                  widget.invoice!.deliveryType == 'Courier')
                                /// Courier popup button
                                _isLoading
                                    ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                    : IconButton(
                                      icon: Icon(
                                        Icons.note_alt_outlined,
                                        color:
                                            _invoice.awbNumber != null
                                                ? Colors.green
                                                : Colors.blue,
                                        size: 32,
                                      ),
                                      onPressed: () async {
                                        final updatedData = await showDialog(
                                          context: context,
                                          builder:
                                              (_) => CourierPopup(
                                                awbNumber: _invoice.awbNumber,
                                                courierCost:
                                                    _invoice.courierCost,
                                                courierRemarks:
                                                    _invoice.courierRemarks,
                                                courierUpdatedTime:
                                                    _invoice.courierUpdatedTime,
                                                courierUpdatedBy:
                                                    _invoice.courierUpdatedBy,
                                              ),
                                        );

                                        if (updatedData != null) {
                                          await _submitUpdates(updatedData);
                                        }
                                      },
                                    ),

                              if (widget.invoice?.invoiceCurrentStatus !=
                                      null &&
                                  (widget.invoice!.invoiceCurrentStatus <= 4 ||
                                      widget.invoice!.invoiceCurrentStatus ==
                                          11) &&
                                  widget.invoice!.tripID == 0 &&
                                  widget.invoice!.actionAllowed == 1)
                                IconButton(
                                  icon: Icon(
                                    deliveryTypeIconData,
                                    color:
                                        (deliveryTypeIconData ==
                                                Icons.fire_truck)
                                            ? Colors.blue
                                            : Colors.red,
                                    size: 32,
                                  ),
                                  onPressed:
                                      () => _openDeliveryTypePopup(
                                        widget.invoice!.deliveryType,
                                      ),
                                ),
                              if (widget.invoice?.invoiceCurrentStatus !=
                                      null &&
                                  (widget.invoice!.invoiceCurrentStatus <= 4 ||
                                      widget.invoice!.invoiceCurrentStatus ==
                                          11) &&
                                  widget.invoice!.tripID == 0 &&
                                  widget.invoice!.actionAllowed == 1)
                                IconButton(
                                  icon: Icon(
                                    Icons.edit_location,
                                    color: Colors.black,
                                    size: 32,
                                  ),

                                  onPressed:
                                      () => _openBranchPopup(
                                        preSelectedBranchId,
                                        context,
                                      ),
                                ),
                            ],
                          ),
                          ...itemDetails.map(
                            (item) => Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                title: Text(
                                  item['item_name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['item_sku']),
                                    Text(
                                      "Quantity: ${item['item_qty']} ${item['item_unit']}",
                                    ),
                                    Text("S.No: ${item['item_sno']}"),
                                  ],
                                ),
                                leading: const Icon(Icons.inventory),
                              ),
                            ),
                          ),

                          if (departmentId == 1) ...[
                            if (showCollectionPrompt) ...[
                              buildCollectionUpdatePrompt(),
                            ] else if (widget.invoice!.codFlag == '1' &&
                                (widget.invoice!.deliveryType ==
                                        'Customer Collection' ||
                                    widget.invoice!.deliveryType ==
                                        'Courier') &&
                                (widget.invoice!.salesType == 'Regular' ||
                                    widget.invoice!.salesType == 'e-Store' ||
                                    widget.invoice!.salesType ==
                                        'Cash Counter') &&
                                (widget.invoice!.paymentStatus == 'Unpaid' ||
                                    widget.invoice!.allPdfSigned ==
                                        'unsigned')) ...[
                              buildUnpaidCODWarning(),
                            ] else if (widget.invoice!.invoiceCurrentStatus ==
                                8) ...[
                              const SizedBox(height: 20),
                              Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 10),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.block,
                                              color: Colors.white70,
                                            ),
                                            label: Text(
                                              'The invoice is canceled',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 16,
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                            onPressed: () {}, // Disabled
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if ((widget.invoice!.invoiceCurrentStatus <=
                                        2 ||
                                    widget.invoice!.invoiceCurrentStatus ==
                                        11) &&
                                widget.invoice!.actionAllowed == 1) ...[
                              const SizedBox(height: 20),
                              Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 10),
                                      Text(
                                        "Select Pickup Team Members",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children:
                                            pickupPersons.map((person) {
                                              return FilterChip(
                                                label: Text(
                                                  person.pkName ?? '',
                                                ),
                                                selectedColor: colorInfo,
                                                checkmarkColor: Colors.white,
                                                selected:
                                                    selectedPickupPersonIds
                                                        .contains(person.pkId),
                                                onSelected: (isSelected) {
                                                  setState(() {
                                                    if (isSelected) {
                                                      selectedPickupPersonIds
                                                          .add(person.pkId!);
                                                    } else {
                                                      selectedPickupPersonIds
                                                          .remove(person.pkId);
                                                    }
                                                  });
                                                },
                                              );
                                            }).toList(),
                                      ),
                                      const SizedBox(height: 20),
                                      if (widget
                                                  .invoice!
                                                  .invoiceCurrentStatus ==
                                              8 ||
                                          widget.invoice!.holdStatus == 9 ||
                                          widget.invoice!.holdStatus == 10)
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.block,
                                                color: Colors.white70,
                                              ),
                                              label: Text(
                                                buttonText.toString(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 16,
                                                ),
                                                backgroundColor: Colors.grey,
                                              ),
                                              onPressed: null, // Disabled
                                            ),
                                            const SizedBox(height: 6),

                                            Text(
                                              'The invoice is on ${(getInitialAction(invoiceCurrentStatus: widget.invoice!.invoiceCurrentStatus, holdStatus: widget.invoice!.holdStatus) as String?)?.lowercaseFirst() ?? ''}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.check_circle_outline,
                                            ),
                                            label: Text(buttonText.toString()),
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                            onPressed: assignToPicking,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            if (invoiceCurrentStatus == 3 ||
                                invoiceCurrentStatus == 4) ...[
                              const SizedBox(height: 20),
                              if (widget.invoice!.codFlag == '1' &&
                                  (widget.invoice!.deliveryType ==
                                          'Customer Collection' ||
                                      widget.invoice!.deliveryType ==
                                          'Courier') &&
                                  (widget.invoice!.salesType == 'Regular' ||
                                      widget.invoice!.salesType == 'e-Store' ||
                                      widget.invoice!.salesType ==
                                          'Cash Counter')) ...[
                                if (widget.invoice!.invoiceCurrentStatus ==
                                    11) ...[
                                  if (widget.invoice!.paymentStatus ==
                                          'Unpaid' ||
                                      widget.invoice!.allPdfSigned ==
                                          'unsigned')
                                    buildCollectionUpdatePrompt()
                                  else
                                    buildConfirmCompleteButton(),
                                  //widget.invoice?.actionAllowed != 1 checked in function
                                ] else ...[
                                  if ((widget.invoice!.paymentStatus ==
                                              'Paid' ||
                                          widget.invoice!.paymentStatus ==
                                              'Proceed without payment') &&
                                      widget.invoice!.allPdfSigned == 'signed')
                                    // buildConfirmCompleteButton(),
                                    if (invoiceCurrentStatus == 4)
                                      buildConfirmSignCompleteButton()
                                    else
                                      buildConfirmCompleteButton(),

                                  //widget.invoice?.actionAllowed != 1 checked in function
                                ],
                              ] else if (widget.invoice!.codFlag == '0' &&
                                  (widget.invoice!.deliveryType ==
                                          'Customer Collection' ||
                                      widget.invoice!.deliveryType ==
                                          'Courier') &&
                                  widget.invoice!.actionAllowed == 1) ...[
                                buildConfirmSignCompleteButton(),
                              ] else
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if ((widget.invoice!.invoiceCurrentStatus ==
                                                8 ||
                                            widget.invoice!.holdStatus == 9 ||
                                            widget.invoice!.holdStatus == 10) &&
                                        widget.invoice!.actionAllowed == 1) ...[
                                      Center(
                                        child: StretchableButton(
                                          onPressed: () {},
                                          buttonColor: Colors.grey,
                                          children: const [
                                            Icon(
                                              Icons.block,
                                              color: Colors.white70,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              "Confirm and Proceed to Load",
                                              style: TextStyle(
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'The invoice is on ${(getInitialAction(invoiceCurrentStatus: widget.invoice!.invoiceCurrentStatus, holdStatus: widget.invoice!.holdStatus) as String?)?.lowercaseFirst() ?? ''}',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ] else
                                      (widget.invoice!.actionAllowed == 1 &&
                                              widget
                                                      .invoice!
                                                      .invoiceCurrentStatus !=
                                                  4)
                                          ? Center(
                                            child: StretchableButton(
                                              onPressed:
                                                  assignToReadyForLoading,
                                              buttonColor: colorInputSuccess,
                                              children: const [
                                                Icon(
                                                  Icons.check_circle_outline,
                                                  color: colorBlack,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Confirm and Proceed to Load",
                                                  style: TextStyle(
                                                    color: colorBlack,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : const SizedBox.shrink(),
                                  ],
                                ),
                            ],
                          ],
                          // 🔹 Your item details
                          const SizedBox(height: 16),
                          // 🔹 Invoice timeline
                          itemStatus.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : buildInvoiceTimeline(itemStatus),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget buildConfirmCompleteButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: StretchableButton(
            onPressed: completeInvoice,
            buttonColor: Colors.green.shade600,
            children: const [
              Icon(Icons.check_circle_outline, color: colorBlack),
              SizedBox(width: 8),
              Text(
                "Confirm, Load & Complete",
                style: TextStyle(color: colorBlack),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildConfirmSignCompleteButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: StretchableButton(
            buttonColor: Colors.green.shade600,
            onPressed: () {
              if (widget.invoice!.allPdfSigned == 'signed') {
                // ✅ Proceed if all PDFs are signed
                completeInvoice();
              } else {
                // ❗ Show popup if signature missing
                showDialog(
                  context: context,
                  builder: (BuildContext ctx) {
                    return AlertDialog(
                      title: const Text('Signature Required'),
                      content: const Text(
                        'Please get the customer\'s signature before completing the invoice.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('OK'),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            children: [
              const Icon(Icons.check_circle_outline, color: colorBlack),
              const SizedBox(width: 8),
              Text(
                widget.invoice!.allPdfSigned == 'signed'
                    ? "Confirm & Complete"
                    : "Confirm, Sign & Complete",
                style: const TextStyle(color: colorBlack),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCollectionUpdatePrompt() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "The document indicates it's a customer collection.\nWould you like to update it?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            RadioListTile<String>(
              title: const Text("Customer Collection"),
              value: "Customer Collection",
              groupValue: _selectedDeliveryType,
              onChanged: (val) => setState(() => _selectedDeliveryType = val),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              contentPadding: EdgeInsets.zero,
            ),
            RadioListTile<String>(
              title: const Text("Courier"),
              value: "Courier",
              groupValue: _selectedDeliveryType,
              onChanged: (val) => setState(() => _selectedDeliveryType = val),
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomCenter,
              child: ElevatedButton.icon(
                icon:
                    _isSubmitting
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.check),
                label: const Text("Submit"),
                onPressed: _isSubmitting ? null : _submitDeliveryTypeUpdate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUnpaidCODWarning() {
    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pickup team assignment is not permitted due to the following reasons:",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "\n* Payment status must be set to either 'Receive Payment' or 'Proceed without Payment'\n\n"
                    "* Delivery type must be either 'Customer Collection' or 'Courier'\n\n"
                    "* All PDF documents must be signed",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildUnSignedWarning() {
    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Pickup team assignment is currently not allowed as the PDF documents have not been signed",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.deepOrangeAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
