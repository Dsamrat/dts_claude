import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import '../constants/common.dart';
import '../services/vehicle_service.dart';
import '../utils/user_preferences.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/navbar.dart';

class VehicleForm extends StatefulWidget {
  final Map<String, dynamic>? vehicle; // For edit

  VehicleForm({super.key, this.vehicle});

  @override
  State<VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<VehicleForm> {
  final _vehicleService = VehicleService();
  final _formKey = GlobalKey<FormState>();
  int? selectedDriver;
  int? selectedVehicle;
  int? currentUserId;
  int? currentUserBranchId;
  int? viewOnly;
  List<int> selectedAssociateDrivers = [];
  List<Map<String, dynamic>> selectedInvoices = [];

  List<dynamic> drivers = [];
  List<dynamic> delSupports = [];
  List<dynamic> vehicles = [];

  bool loading = false;
  bool loadFailed = false;
  @override
  void initState() {
    super.initState();
    initForm();
  }

  Future<void> initForm() async {
    var gotUserDetails = await UserPreferences.getUserDetails();
    // print(jsonEncode(gotUserDetails));
    currentUserId = gotUserDetails['userId'];
    currentUserBranchId = gotUserDetails['branchId'];
    viewOnly = gotUserDetails['viewOnly'];
    // print('viewOnly $viewOnly');
    // print('currentUserBranchId $currentUserBranchId');
    await fetchInitialData();
    if (widget.vehicle != null) {
      loadVehicleData(widget.vehicle!);
    }
    setState(() {}); // Update the UI
  }

  Future<void> fetchInitialData() async {
    try {
      setState(() {
        loading = true;
        loadFailed = false;
      });
      drivers = await _vehicleService.fetchDrivers(
        currentUserBranchId!,
        widget.vehicle?['as_driver_id'],
      );
      delSupports = await _vehicleService.fetchDeliverySupports(
        currentUserBranchId!,
        widget.vehicle?['as_id'],
      );
      vehicles = await _vehicleService.fetchVehicles(
        currentUserBranchId!,
        widget.vehicle?['as_vehicle_id'],
      );
      if (kDebugMode) {
        print('✅ Vehicles Loaded: ${vehicles.length}');
        print(
          '🔍 First Vehicle: ${vehicles.isNotEmpty ? vehicles[0] : 'No vehicles'}',
        );
      }
    } catch (e) {
      // print(e);
      loadFailed = true;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load data: $e')));
    } finally {
      setState(() => loading = false);
    }
  }

  void loadVehicleData(Map<String, dynamic> vehicle) {
    selectedVehicle = vehicle['as_vehicle_id'];
    selectedDriver = vehicle['as_driver_id'];

    selectedAssociateDrivers =
        vehicle['as_associate_driver'] != null
            ? List<int>.from(vehicle['as_associate_driver'])
            : [];
  }

  Future<void> saveVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      "vehicle_id": selectedVehicle, // Hardcoded now, replace if needed
      "driver_id": selectedDriver,
      "associate_drivers": selectedAssociateDrivers,
      "currentUserId": currentUserId,
      "currentUserBranchId": currentUserBranchId,
    };

    setState(() => loading = true);

    bool success;
    if (widget.vehicle != null) {
      success = await _vehicleService.updateVehicle(
        widget.vehicle!['as_id'],
        data,
      );
    } else {
      success = await _vehicleService.createVehicle(data);
    }

    setState(() => loading = false);

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save trip.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(
        title: widget.vehicle == null ? "Create Vehicle" : "Edit Vehicle",
        backButton: true,
      ),
      body: Stack(
        children: [
          backgroundAllScreen(),
          loading
              ? Center(child: CircularProgressIndicator())
              : loadFailed
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Failed to load form data."),
                    SizedBox(height: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryTeal,
                      ),
                      onPressed: initForm,
                      child: Text("Retry"),
                    ),
                  ],
                ),
              )
              : Form(
                key: _formKey,
                child: ListView(
                  padding: EdgeInsets.all(16),
                  children: [
                    SizedBox(height: 20),
                    DropdownButtonFormField<int>(
                      value: selectedVehicle,
                      items:
                          vehicles
                              .map(
                                (vehicle) => DropdownMenuItem<int>(
                                  value: vehicle['veh_id'],
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        color:
                                            Colors.black, // default text color
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              '${vehicle["veh_make"]}-${vehicle["veh_model"]}-${vehicle["veh_number_plate"]}-${vehicle["veh_type"]}',
                                        ),
                                        if (vehicle["veh_express"] == 1)
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
                                ),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => selectedVehicle = val),
                      decoration: InputDecoration(
                        labelText: 'Select Vehicle',
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                          fontSize: 12,
                        ),
                      ),
                      validator:
                          (val) => val == null ? 'Select a Vehicle' : null,
                    ),
                    DropdownButtonFormField<int>(
                      value: selectedDriver,
                      items: [
                        const DropdownMenuItem<int>(
                          value: 0, // 👈 represent "no driver"
                          child: Text("No Driver Assigned"),
                        ),
                        ...drivers.map(
                          (driver) => DropdownMenuItem<int>(
                            value: driver['id'],
                            child: Text(driver['name']),
                          ),
                        ),
                      ],
                      onChanged: (val) => setState(() => selectedDriver = val),
                      decoration: InputDecoration(
                        labelText: 'Select Driver',
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                          fontSize: 12,
                        ),
                      ),

                      validator:
                          (val) => val == null ? 'Select a driver' : null,
                    ),

                    SizedBox(height: 20),
                    MultiSelectDialogField(
                      items:
                          delSupports
                              .map(
                                (delSup) => MultiSelectItem<int>(
                                  int.parse(delSup['id'].toString()),
                                  delSup['name'],
                                ),
                              )
                              .toList(),
                      initialValue: selectedAssociateDrivers,
                      title: Text("Delivery Support"),
                      buttonText: Text(
                        "Select Delivery Support",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                          fontSize: 12,
                        ),
                      ),
                      onConfirm: (values) {
                        selectedAssociateDrivers = List<int>.from(values);
                      },
                    ),
                    SizedBox(height: 30),
                    if (viewOnly == 0)
                      ElevatedButton(
                        onPressed: saveVehicle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryTeal,
                        ),
                        child: Text('Save'),
                      ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
