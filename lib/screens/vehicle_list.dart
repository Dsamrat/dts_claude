import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/common.dart';
import '../screens/vehicle_form.dart';
import '../services/vehicle_service.dart';
import '../widgets/drawer.dart';
import '../widgets/navbar.dart';
import 'package:dts/widgets/background_allscreen.dart';

class VehicleList extends StatefulWidget {
  const VehicleList({Key? key}) : super(key: key);

  @override
  State<VehicleList> createState() => _VehicleListState();
}

class _VehicleListState extends State<VehicleList> {
  List<dynamic> assingedVehicles = [];
  bool loading = true;
  bool loadFailed = false;
  final _vehicleService = VehicleService();
  int? currentUserBranchId;
  int? viewOnly;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    await loadUserDetails();
    await loadAssignedVehicles(currentUserBranchId);
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    currentUserBranchId = prefs.getInt('branchId');
    viewOnly = prefs.getInt('viewOnly');
    // print('laravel app ${prefs.getString('appVersion')}');
  }

  Future<void> loadAssignedVehicles(currentUserBranchId) async {
    try {
      final data = await _vehicleService.fetchAssignedVehicles(
        currentUserBranchId!,
      );
      setState(() {
        assingedVehicles = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loadFailed = true;
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading vehicles: $e')));
      }
    }
  }

  Future<void> deleteVehicle(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Delete Vehicle'),
            content: Text('Are you sure you want to delete this vehicle?'),
            actions: [
              TextButton(
                child: Text('Cancel'),
                onPressed: () => Navigator.pop(ctx, false),
              ),
              TextButton(
                child: Text('Delete'),
                onPressed: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      try {
        await _vehicleService.deleteVehicle(id);
        loadAssignedVehicles(currentUserBranchId);

        // ✅ optional success toast/snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vehicle deleted successfully")),
        );
      } catch (e) {
        // ✅ show API error nicely
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
    // if (confirmed == true) {
    //   await _vehicleService.deleteVehicle(id);
    //   loadAssignedVehicles(currentUserBranchId);
    // }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(title: "Vehicles"),
      extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Vehicles"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          loading
              ? const Center(child: CircularProgressIndicator())
              : loadFailed
              ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Failed to load vehicle data."),
                    SizedBox(height: 10),
                  ],
                ),
              )
              : assingedVehicles.isEmpty
              ? const Center(
                child: Text(
                  "No records found",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : RefreshIndicator(
                onRefresh: initialize,
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 120),
                  itemCount: assingedVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = assingedVehicles[index];

                    return Card(
                      color: Colors.white.withOpacity(0.9),
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🔹 Left side: Vehicle, Driver, Associate Drivers
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${vehicle["vehicle"]}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: secondaryTeal,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${vehicle["driver"]}',
                                    style: const TextStyle(
                                      color: primaryTeal,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (vehicle["associate_driver_names"] !=
                                          null &&
                                      vehicle["associate_driver_names"]
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      '${vehicle["associate_driver_names"]}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // 🔹 Right side: Express + Edit + Delete stacked
                            Column(
                              children: [
                                if (vehicle['vehicle_express'] == 1)
                                  const Padding(
                                    padding: EdgeInsets.zero,
                                    child: expressDelivery,
                                  ),
                                Row(
                                  children: [
                                    IconButton(
                                      padding:
                                          EdgeInsets
                                              .zero, // remove internal padding
                                      constraints:
                                          const BoxConstraints(), // remove min size (48x48)
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        // size: 20,
                                      ),
                                      tooltip: "Edit Vehicle",
                                      onPressed: () async {
                                        final updated = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => VehicleForm(
                                                  vehicle: vehicle,
                                                ),
                                          ),
                                        );
                                        if (updated == true) {
                                          loadAssignedVehicles(
                                            currentUserBranchId,
                                          );
                                        }
                                      },
                                    ),
                                    if (viewOnly == 0)
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                          // size: 20,
                                        ),
                                        tooltip: "Delete Vehicle",
                                        onPressed: () {
                                          deleteVehicle(vehicle['as_id']);
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
        ],
      ),

      floatingActionButton:
          (viewOnly == 0)
              ? FloatingActionButton(
                onPressed: () async {
                  final created = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => VehicleForm()),
                  );
                  if (created == true)
                    loadAssignedVehicles(currentUserBranchId);
                },
                child: const Icon(Icons.add),
                backgroundColor: secondaryTeal,
              )
              : null,
    );
  }
}
