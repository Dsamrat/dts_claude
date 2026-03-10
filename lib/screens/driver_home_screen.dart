import 'package:dts/screens/view_payment_form.dart';
import 'package:dts/utils/string_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/common.dart';
import '../models/delivery_remakrs.dart';
import '../models/issue_remark.dart';
import '../services/api.dart';
import '../services/driver_service.dart';
import '../services/pusher_service.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/build_flag.dart';
import '../widgets/common_pdf_icon.dart';
import '../widgets/drawer.dart';
import '../widgets/hold_cancel_info.dart';
import '../widgets/navbar.dart';
import '../widgets/trip_status.dart';
import 'invoice_sign_page.dart';
import 'make_payment_form.dart';
import 'package:geolocator/geolocator.dart';

import '../utils/pusher_connector_interface.dart' as connector_interface;
import '../utils/pusher_connector_stub_impl.dart'
    if (dart.library.js) '../utils/pusher_connector_web_impl.dart'
    if (dart.library.io) '../utils/pusher_connector_stub_impl.dart'
    as connector_impl;

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({Key? key}) : super(key: key);
  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  List<dynamic> trips = [];
  bool isLoading = true;
  final DriverService _driverService = DriverService();
  int? currentUserBranchId;
  int? currentUserId;
  int? userDepartmentId;
  final kmController = TextEditingController();
  final endKmController = TextEditingController();
  final _startKmFormKey = GlobalKey<FormState>();
  final _endKmFormKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  String? selectedIssue; // This holds the previously selected issue

  List<IssueRemark> issueRemarks = [];
  List<DeliveryRemarks> deliveryRemarks = [];
  bool isLoadingIssues = true;
  List<String> issues = [
    "Customer closed",
    "Delay due to traffic",
    "Delay in payment",
    "Delay in unloading",
    "Delay in document signing",
    "Vehicle breakdown",
    "Others",
  ];

  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;
  @override
  void initState() {
    super.initState();
    _loadIssues();
    _loadRemarks();
    _pusherConnector = connector_impl.createPusherConnector();
    _initialize(); // ✅ call async function without await
  }

  Future<void> _loadIssues() async {
    issueRemarks = await _driverService.fetchIssueRemarks();
    setState(() {
      isLoadingIssues = false;
    });
  }

  Future<void> _loadRemarks() async {
    deliveryRemarks = await _driverService.fetchDeliveryRemarks();
    setState(() {
      isLoadingIssues = false;
    });
  }

  void _showDeliveryRemarksDialog(BuildContext context, int invoiceId) {
    String? selectedRemark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: const Text('Select Remark'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children:
                      deliveryRemarks.map((r) {
                        return RadioListTile<String>(
                          value: r.remarks, // 👈 text as value
                          groupValue: selectedRemark,
                          title: Text(r.remarks),
                          onChanged: (value) {
                            setState(() {
                              selectedRemark = value;
                            });
                          },
                        );
                      }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed:
                      selectedRemark == null
                          ? null
                          : () {
                            Navigator.pop(ctx);
                            _showFinalConfirmation(
                              context,
                              invoiceId,
                              selectedRemark!, // 👈 pass text
                            );
                          },
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFinalConfirmation(
    BuildContext context,
    int invoiceId,
    String remark,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Confirm Delivery Completion'),
          content: Text(
            'You selected:\n\n"$remark"\n\n'
            'This action cannot be reverted. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                updateDeliveryCompleted(invoiceId, remark);
              },
              child: const Text('Yes, Complete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateDeliveryCompleted(int invoiceId, String remarks) async {
    setState(() => _isSubmitting = true);
    try {
      final postData = {
        'invoice_id': invoiceId,
        // 'currentUserBranchId': currentUserBranchId,
        'currentUserId': currentUserId,
        // 'userDepartmentId': userDepartmentId,
        'remarks': remarks,
      };

      final message = await _driverService.updateDeliveryCompleted(postData);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));

      await fetchTrips();
    } catch (e) {
      debugPrint("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to change the status as delivered'),
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _initialize() async {
    await _loadUserDetails();
    if (kIsWeb && !_pusherInitialized) {
      _initializePusherWeb();
      _pusherInitialized = true;
    } else if (!kIsWeb) {
      await initPusher();
    }
  }

  void _initializePusherWeb() {
    final channelNameWeb = 'trip-$currentUserBranchId';
    const String eventNameWeb = 'trip.created'; // Example dynamic value

    _pusherConnector.initPusherWeb(
      channelNameWeb,
      eventNameWeb,
      (raw) => _handlePusherEventWeb(raw), // call async inside sync wrapper
    );
  }

  Future<void> _handlePusherEventWeb(dynamic raw) async {
    try {
      await fetchTrips();
    } catch (e, st) {
      debugPrint("❌ Error in _handlePusherEventWeb: $e");
      debugPrint("$st");
    }
  }

  Future<void> initPusher() async {
    final pusherService = PusherService(
      apiKey: pusherAPIKey,
      cluster: pusherCluster,
      authEndpoint: pusherAuthURl,
      userToken: '',
    );
    final channelName = 'trip-$currentUserBranchId'; // ✅ no extra space
    debugPrint("📡 Subscribing to Pusher channel: $channelName");
    pusherService.on(channelName, 'trip.created', (data) async {
      debugPrint("Trip created event received: $data");
      await fetchTrips();
    });
    await pusherService.init();
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserBranchId = prefs.getInt('branchId');
      currentUserId = prefs.getInt('userId');
      userDepartmentId = prefs.getInt('departmentId');
      if (currentUserId != null) {
        fetchTrips();
      }
    });
  }

  Future<void> fetchTrips() async {
    try {
      final tripsData = await _driverService.fetchDriverTrips(currentUserId!);
      setState(() {
        trips = tripsData;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching trips: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load trips')));
    }
  }

  Future<void> submitInvoiceIssue(
    int invoiceId,
    String? remarks,
    int? affectFlag,
  ) async {
    await _driverService.submitInvoiceIssue(invoiceId, remarks, affectFlag);
  }

  void _openMap(double? latitude, double? longitude) async {
    debugPrint('build invoice $latitude');
    if (latitude == null || longitude == null) return;

    final Uri googleUrl = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (await canLaunchUrl(googleUrl)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _endTrip(tripID) async {
    setState(() => _isSubmitting = true);

    String latitude = '';
    String longitude = '';

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final locationSettings = LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 0,
            timeLimit: Duration(seconds: 5),
          );
          final position = await Geolocator.getCurrentPosition(
            locationSettings: locationSettings,
          );
          latitude = position.latitude.toString();
          longitude = position.longitude.toString();
        }
      }
    } catch (e) {
      debugPrint("❌ Error getting location: $e");
    }

    try {
      final postData = {
        'currentUserId': currentUserId,
        'tripId': tripID,
        'endKm': endKmController.text,
        'latitude': latitude,
        'longitude': longitude,
      };

      await _driverService.updateTripCompleted(postData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trip updated successfully')),
      );

      await fetchTrips();
    } catch (e) {
      debugPrint("❌ Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to end trip')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showIssueSelectionDialog(BuildContext context, Map invoice) {
    final String? currentRemark = invoice['issue_remark'];

    // Create local list
    final List<IssueRemark> dialogIssues = List.from(issueRemarks);

    final bool hasSelection = currentRemark != null && currentRemark.isNotEmpty;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select an issue during Delivery"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: dialogIssues.length + (hasSelection ? 1 : 0),
              itemBuilder: (context, index) {
                // 🔴 Remove selection
                if (hasSelection && index == 0) {
                  return ListTile(
                    title: const Text(
                      "Remove selection",
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () async {
                      await _driverService.submitInvoiceIssue(
                        invoice['invoice_id'],
                        "",
                        0,
                      );

                      setState(() {
                        invoice['issue_remark'] = "";
                        invoice['affect_flag'] = null;
                      });

                      Navigator.pop(context);
                    },
                  );
                }

                final IssueRemark issue =
                    dialogIssues[hasSelection ? index - 1 : index];

                final bool isSelected = issue.remarks == currentRemark;

                return ListTile(
                  tileColor:
                      isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                  title: Text(
                    issue.remarks,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () async {
                    await _driverService.submitInvoiceIssue(
                      invoice['invoice_id'],
                      issue.remarks,
                      issue.affectFlag,
                    );

                    setState(() {
                      invoice['issue_remark'] = issue.remarks;
                      invoice['affect_flag'] = issue.affectFlag;
                    });

                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(title: "Deliveries"),
      // extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Deliveries"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : trips.isEmpty
              ? const Center(
                child: Text(
                  "No records found",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : RefreshIndicator(
                onRefresh: fetchTrips,
                child: ListView.separated(
                  padding: const EdgeInsets.all(1),
                  itemCount: trips.length,
                  separatorBuilder:
                      (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, tripIndex) {
                    final trip = trips[tripIndex];
                    return _buildTripCard(trip, context);
                  },
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildTripCard(trip, BuildContext context) {
    final List invoices = trip['invoices'] as List;
    bool allInvoicesHave(String key, dynamic value) =>
        invoices.isNotEmpty &&
        invoices.every((invoice) => invoice[key] == value);

    final bool allInvoicesStatus5 = allInvoicesHave('invoice_status', 'Loaded');
    final bool notDeliverable =
        invoices.isNotEmpty &&
        invoices.any((invoice) => invoice['invoice_status_integer'] != 7);

    final bool allInvoicesDelivered =
        invoices.isNotEmpty &&
        invoices.every(
          (invoice) =>
              [7, 8].contains(invoice['invoice_status_integer']) ||
              [9, 10].contains(invoice['holdStatus']),
        );
    final bool allCashCollected =
        invoices.isNotEmpty &&
        invoices.every(
          (invoice) =>
              invoice['cod_status'] == 1 ||
              invoice['invoice_status_integer'] == 8 ||
              [9, 10].contains(invoice['holdStatus']),
        );
    final int loadedCount =
        invoices
            .where((invoice) => invoice['invoice_status'] == 'Loaded')
            .length;

    final int holdCount =
        invoices
            .where(
              (invoice) =>
                  invoice['invoice_status_integer'] == 8 ||
                  [9, 10].contains(invoice['holdStatus']),
            )
            .length;

    final bool countsNotEqual = loadedCount != holdCount;

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
                if (trip['veh_express'] == 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: expressDelivery,
                  ),

                //popupmenubutton
              ],
            ),
            TripStatusFlag(startKm: trip['start_km'], endKm: trip['end_km']),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                        if (trip['start_km'] > 0)
                          Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Start KM: ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '${trip['start_km']}'),
                                if (trip['end_km'] > 0) ...[
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
                trip['start_km'],
              ),
            /*START*/
            if (allInvoicesStatus5 && countsNotEqual)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Form(
                  key: _startKmFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enter Kilometer",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      TextFormField(
                        controller: kmController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Enter Kilometer',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Kilometer is required';
                          }

                          final number = num.tryParse(value);
                          if (number == null) {
                            return 'Enter a valid Kilometer';
                          }

                          if (number <= 0) {
                            return 'Kilometer must be greater than zero';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () async {
                                  if (_startKmFormKey.currentState!
                                      .validate()) {
                                    setState(
                                      () => _isSubmitting = true,
                                    ); // Start spinner

                                    final km = kmController.text;
                                    try {
                                      final postData = {
                                        'currentUserId': currentUserId,
                                        'tripId': trip['trip_id'],
                                        'startKm': km,
                                      };
                                      await _driverService
                                          .updateDispatchedStatus(postData);

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Trip updated successfully',
                                          ),
                                        ),
                                      );

                                      await fetchTrips(); // Reload the data
                                    } catch (e) {
                                      print('Error: $e');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to start trip'),
                                        ),
                                      );
                                    } finally {
                                      setState(
                                        () => _isSubmitting = false,
                                      ); // Stop spinner
                                    }
                                  }
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                        ),
                        child:
                            _isSubmitting
                                ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : Text('Start Trip'),
                      ),
                    ],
                  ),
                ),
              ),
            if (allInvoicesDelivered &&
                allCashCollected &&
                trip['start_km'] > 0 &&
                trip['end_km'] == 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Form(
                  key: _endKmFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: endKmController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Enter End Kilometer',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'End Kilometer is required';
                          }

                          final number = num.tryParse(value);
                          if (number == null) {
                            return 'Enter a valid End Kilometer';
                          }

                          if (number <= 0) {
                            return 'End Kilometer must be greater than zero';
                          }
                          if (number <= trip['start_km']) {
                            return 'End Kilometer must be greater than start kilometer';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed:
                            _isSubmitting
                                ? null
                                : () async {
                                  if (!_endKmFormKey.currentState!.validate())
                                    return;

                                  if (notDeliverable == true &&
                                      trip['veh_express'] == 0) {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder:
                                          (context) => AlertDialog(
                                            title: const Text("Confirmation"),
                                            content: const Text(
                                              "Could you please confirm whether items has been offloaded ?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(false),
                                                child: const Text("Cancel"),
                                              ),
                                              ElevatedButton(
                                                onPressed:
                                                    () => Navigator.of(
                                                      context,
                                                    ).pop(true),
                                                child: const Text(
                                                  "Yes, Confirm",
                                                ),
                                              ),
                                            ],
                                          ),
                                    );

                                    if (confirmed != true) {
                                      return; // ❌ User cancelled
                                    }
                                  }
                                  await _endTrip(trip['trip_id']);
                                },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                        ),
                        child:
                            _isSubmitting
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('End Trip'),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildInvoicesExpansionTile(List invoices, startKm) {
    final deliveredCount =
        invoices.where((inv) => inv['invoice_status_integer'] == 7).length;
    return ExpansionTile(
      leading: const Icon(Icons.receipt_long),
      title: Text(
        'Invoices($deliveredCount/${invoices.length})',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),

      children:
          invoices
              .map((invoice) => _buildInvoiceItem(invoice, startKm))
              .toList(),
    );
  }

  Widget _buildPdfIcons(
    BuildContext context,
    Map<String, dynamic> invoice,
    startKm,
    isDisabled,
  ) {
    List<Widget> pdfWidgets = [];

    final List<dynamic>? pdfsData = invoice['pdfs'] as List<dynamic>?;
    if (pdfsData != null && pdfsData.isNotEmpty) {
      for (var pdfJson in pdfsData) {
        final String? docType = pdfJson['doc_type'] as String?;
        final String? pdfLink = pdfJson['pdf_link'] as String?;
        final int? startKiloMeter = int.tryParse(startKm.toString());
        final String? signedPdfLink = pdfJson['signed_pdf_link'] as String?;
        final int? pdfId = pdfJson['pdf_id'] as int?;
        final String? linkToOpen =
            signedPdfLink?.isNotEmpty == true ? signedPdfLink : pdfLink;
        if (linkToOpen?.isNotEmpty == true) {
          pdfWidgets.add(
            IgnorePointer(
              ignoring: isDisabled, // true = disables tap
              child: InkWell(
                onTap: () {
                  if (pdfJson['getSign'] == 1) {
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
                            (context) => InvoiceSignPage(
                              pdfLink: linkToOpen!,
                              docType: docType!,
                              invoiceNum:
                                  pdfJson['resolved_doc_num']?.toString() ??
                                  'N/A',
                              invoiceId: pdfJson['pdf_invoice_id'],
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
                  }
                },
                child: Tooltip(
                  message:
                      pdfJson['signed_pdf_link'] != null &&
                              pdfJson['signed_pdf_link']!.isNotEmpty
                          ? 'Signed ' + pdfJson['doc_type']
                          : 'Unsigned ' + pdfJson['doc_type'],
                  child: Icon(
                    pdfJson['doc_type'] == 'Invoice'
                        ? Icons.request_quote
                        : Icons.description,
                    color:
                        isDisabled
                            ? Colors
                                .grey // visually show disabled
                            : (pdfJson['signed_pdf_link'] != null &&
                                    pdfJson['signed_pdf_link']!.isNotEmpty
                                ? Colors.blue
                                : Colors.red),
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

  Widget _buildInvoiceItem(invoice, startKm) {
    final cardBGColor = getInvoiceCardBGColor(
      invoiceCurrentStatus: invoice['invoice_status_integer'],
      holdStatus: invoice['holdStatus'],
    );
    final isDisabled = isInvoiceDisabledExcludeReschedule(
      invoice['invoice_status_integer'],
      invoice['holdStatus'],
    );
    final bool isDeliveryCompleted =
        invoice['invoice_status_integer'] == 7 &&
        invoice['delivery_remark'] != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 4),
      decoration: BoxDecoration(
        color: cardBGColor,
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
                Flexible(
                  // Added Flexible
                  child: Text(
                    invoice['doc_num'] ?? 'Invoice',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: secondaryTeal,
                    ),
                    overflow:
                        TextOverflow.ellipsis, // Add ellipsis for long doc_num
                    maxLines: 2, // Ensure it stays on one line
                  ),
                ),
                Flexible(
                  child: buildFlag(
                    invoice['invoice_status']?.toString() ?? 'Unknown',
                    getStatusColor(invoice['invoice_status_integer']),
                  ),
                ),
                const SizedBox(height: 1),

                // Wrap buildFlag
              ],
            ),
            if (invoice['otherBranchDel'] == 1)
              (invoice['delFromBranchName'] != null &&
                      invoice['delFromBranchName']!.isNotEmpty)
                  ? Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Delivery From ',
                          style: TextStyle(
                            // fontWeight: FontWeight.bold,
                            color: secondaryTeal,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text:
                              (invoice['delFromBranchName'] as String?)
                                  ?.capitalize(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ), // bold
                        ),
                      ],
                    ),
                  )
                  : const SizedBox.shrink(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (invoice['customer_name']?.isNotEmpty == true)
                  Expanded(
                    child: Text(
                      (invoice['customer_name'] as String?)?.toTitleCase() ??
                          '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                if (invoice['expressFlag']?.toLowerCase() != 'exp')
                  buildFlag(
                    invoice['trip_sort'].toString(),
                    Colors.yellow.shade900,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, color: Colors.redAccent),
                    const SizedBox(width: 2),

                    Expanded(
                      // 👈 wrap text so it can break lines
                      child:
                          ((invoice['cus_distance'] != null &&
                                      invoice['cus_distance']
                                          .toString()
                                          .isNotEmpty &&
                                      invoice['cus_distance']
                                              .toString()
                                              .toLowerCase() !=
                                          'unknown') ||
                                  (invoice['subLocality'] != null &&
                                      invoice['subLocality']
                                          .toString()
                                          .isNotEmpty))
                              ? Text(
                                [
                                  if (invoice['cus_distance'] != null &&
                                      invoice['cus_distance']
                                          .toString()
                                          .isNotEmpty &&
                                      invoice['cus_distance']
                                              .toString()
                                              .toLowerCase() !=
                                          'unknown')
                                    invoice['cus_distance'].toString(),
                                  if (invoice['subLocality'] != null &&
                                      invoice['subLocality']
                                          .toString()
                                          .isNotEmpty)
                                    invoice['subLocality'].toString(),
                                ].join(' • '),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue,
                                ),
                                softWrap: true,
                              )
                              : const Text(
                                "No location info",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
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
                                fontSize: 12,
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
                                fontSize: 12,
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
                        fontSize: 14,
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
                const Icon(
                  Icons.calendar_month,
                  size: 18,
                  color: secondaryTeal,
                ),
                const SizedBox(width: 1),
                Text(
                  invoice['doc_created_at'],
                  style: const TextStyle(
                    fontSize: 12,
                    // fontWeight: FontWeight.bold,
                    color: secondaryTeal,
                  ),
                ),
                const SizedBox(width: 1), // space between the two dates
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
                        fontWeight: FontWeight.bold,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 1,
                    runSpacing: 1,
                    children: [
                      if (invoice['hard_copy'] == 1)
                        buildFlag('H', Colors.orange),

                      if (invoice['hard_copy'] == 1 && invoice['cod_flag'] == 1)
                        const SizedBox(width: 6),

                      if (invoice['cod_flag'] == 1)
                        buildFlag('COD', Colors.green),

                      if (invoice['sign_only'] == 1) ...[
                        const SizedBox(width: 6),
                        buildFlag('Sign Only', Colors.red),
                      ],

                      if ((invoice['expressFlag'] ?? '')
                              .toString()
                              .toLowerCase() ==
                          'exp')
                        expressDelivery,

                      HoldCancelInfo(
                        invoiceCurrentStatus: invoice['invoice_status_integer'],
                        holdStatus: invoice['holdStatus'],
                        holdAt: invoice['holdAt'],
                        holdReason: invoice['holdReason'],
                        holdReschedule: invoice['holdReschedule'],
                      ),
                      if (invoice['otherBranchDel'] == 1)
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
                    // _buildPdfIcons(context, invoice, startKm, isDisabled),
                    CommonPdfIcons(
                      context: context,
                      invoice: invoice,
                      startKm: startKm,
                      isDisabled: isDisabled,
                      screenType: PdfIconScreenType.driver,
                    ),
                    if (isDeliveryCompleted) ...[
                      // const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () {
                          showInfoDialog(
                            context: context,
                            title: 'Closing Remarks',
                            message: invoice['delivery_remark'],
                          );
                        },
                        child: const Icon(
                          Icons.info_outline,
                          size: 30,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],

                    if (invoice['invoice_status_integer'] == 6 ||
                        invoice['invoice_status_integer'] == 7)
                      GestureDetector(
                        onTap: () {
                          _showIssueSelectionDialog(context, invoice);
                        },

                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 30,
                              color:
                                  (invoice['issue_remark'] == null ||
                                          invoice['issue_remark']
                                              .toString()
                                              .isEmpty)
                                      ? Colors.amber
                                      : Colors.green,
                            ),
                            Icon(Icons.error, size: 18, color: Colors.red),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),

            if (isDisabled && invoice['invoice_status_integer'] <= 5)
              Tooltip(
                message: 'Send notification to operation team',
                child: ElevatedButton.icon(
                  onPressed:
                      _isSubmitting
                          ? null
                          : () async {
                            setState(
                              () => _isSubmitting = true,
                            ); // Start spinner
                            try {
                              final postData = {
                                'currentUserId': currentUserId,
                                'invoiceId': invoice['invoice_id'],
                              };
                              await _driverService.removeHoldInvoiceNotify(
                                postData,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Notification sent successfully',
                                  ),
                                ),
                              );
                            } catch (e) {
                              print('Error: $e');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send notification'),
                                ),
                              );
                            } finally {
                              setState(
                                () => _isSubmitting = false,
                              ); // Stop spinner
                            }
                          },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
                  icon:
                      _isSubmitting
                          ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                          ),
                  label: Text('Notify!'),
                ),
              ),

            // const SizedBox(height: 8),
            Row(
              children: [
                // 🔹 LEFT: PAYMENT BUTTON (COD only)
                if (startKm > 0 && invoice['cod_flag'] == 1)
                  if (invoice['cod_status'] == 0)
                    TextButton.icon(
                      onPressed:
                          isDisabled
                              ? null
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
                        color: isDisabled ? Colors.grey : Colors.red,
                      ),
                      label: Text(
                        'Update Payment Info.',
                        style: TextStyle(
                          color: isDisabled ? Colors.grey : Colors.red,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () {
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
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),

                // 🔹 SPACE BETWEEN (only if both buttons exist)
                if (startKm > 0 &&
                    invoice['cod_status'] == 1 &&
                    invoice['invoice_status_integer'] < 7)
                  const Spacer(),

                // 🔹 RIGHT: COMPLETE DELIVERY BUTTON
                if (startKm > 0 &&
                    invoice['cod_status'] == 1 &&
                    invoice['invoice_status_integer'] < 7)
                  TextButton.icon(
                    onPressed: () {
                      _showDeliveryRemarksDialog(
                        context,
                        invoice['invoice_id'],
                      );
                      // _showSyncConfirmation(context, invoice['invoice_id']);
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    label: const Text(
                      'Complete Delivery',
                      style: TextStyle(color: Colors.green),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),

        children: [
          Container(
            color: cardBGColor,

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                const Text(
                  'Items:',
                  style: TextStyle(fontWeight: FontWeight.bold),
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
                                    item['item_loaded'] == 1
                                        ? Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                        )
                                        : Icon(
                                          Icons.radio_button_unchecked,
                                          color: Colors.grey.shade400,
                                        ),
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

  /* void _showSyncConfirmation(BuildContext context, int invoiceId) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Confirm'),
          content: const Text(
            'Are you sure you want to complete this invoice?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                updateDeliveryCompleted(invoiceId);
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }*/
}
