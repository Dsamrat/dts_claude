import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/common.dart';
import '../services/pickup_team_service.dart';
import 'pickup_team_form.dart';

// LOAD WIDGETS
import 'package:dts/widgets/navbar.dart';
import 'package:dts/widgets/drawer.dart';
import '../widgets/background_allscreen.dart';

class PickupTeamList extends StatefulWidget {
  const PickupTeamList({super.key});

  @override
  State<PickupTeamList> createState() => _PickupTeamListState();
}

class _PickupTeamListState extends State<PickupTeamList> {
  int? userBranchId;
  int? viewOnly;
  final PickupTeamService _pickupTeamService = PickupTeamService();
  List<Map<String, dynamic>> pickups = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    loadUserDetails();
    // fetchPickupTeam();
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // userBranchId = prefs.getInt('branchId');
    userBranchId = prefs.getInt('branchId') ?? 0;
    viewOnly = prefs.getInt('viewOnly') ?? 0;
    await fetchPickupTeam();
    // fetchPickupTeam();
  }

  Future<void> fetchPickupTeam() async {
    final data = await _pickupTeamService.getPickupTeams(userBranchId!);

    setState(() {
      pickups = List<Map<String, dynamic>>.from(data);
      loading = false;
    });
  }

  void deletePickupTeam(int id) async {
    await _pickupTeamService.deletePickupTeam(id);
    fetchPickupTeam();
  }

  void openForm({Map<String, dynamic>? pickup}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PickupTeamForm(pickup: pickup)),
    );
    fetchPickupTeam(); // Refresh list after form
  }

  void showAlert(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Alert'),
          content: Text('This is a dummy alert!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(title: "Pickup"),
      extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Pickup"),
      body:
          loading
              ? const Center(child: CircularProgressIndicator())
              : pickups.isEmpty
              ? const Center(
                child: Text(
                  "No records found",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
              : Stack(
                children: [
                  backgroundAllScreen(),
                  Container(color: Colors.black12),
                  ListView.builder(
                    itemCount: pickups.length,
                    itemBuilder: (context, index) {
                      final pickup = pickups[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          title: Text(
                            pickup['name'] ?? 'No Name',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            "Branch: ${pickup['bm_name'] ?? 'Unknown'}\n"
                            "Users: ${(pickup['userNames'] as List<dynamic>?)?.join(', ') ?? 'None'}",
                          ),
                          trailing:
                              (viewOnly == 0)
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit),
                                        onPressed: () {
                                          openForm(pickup: pickup);
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () {
                                          // print("delete item: $pickup['id']");
                                          deletePickupTeam(pickup['id']);
                                        },
                                      ),
                                    ],
                                  )
                                  : null,
                        ),
                      );
                    },
                  ),
                ],
              ),
      floatingActionButton:
          (viewOnly == 0)
              ? FloatingActionButton(
                onPressed: () => openForm(),
                child: const Icon(Icons.add),
                backgroundColor: secondaryTeal,
              )
              : null,
    );
  }
}
