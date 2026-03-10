import 'package:flutter/material.dart';
import 'package:dts/widgets/navbar.dart';
import 'package:dts/widgets/drawer.dart';
import 'package:dts/widgets/input.dart';
import 'package:dts/widgets/button.dart';
import 'package:dts/constants/common.dart';
import 'package:dts/widgets/custom_dropdown.dart';
import 'package:form_validation/form_validation.dart';

import '../services/pickup_team_service.dart';
import 'package:dts/widgets/background_allscreen.dart';
/*BRANCH SECTION*/
import '../models/branch.dart';
import '../services/branch_service.dart';

class PickupTeamForm extends StatefulWidget {
  final Map<String, dynamic>? pickup;
  const PickupTeamForm({super.key, this.pickup});

  @override
  State<PickupTeamForm> createState() => _PickupTeamFormState();
}

class _PickupTeamFormState extends State<PickupTeamForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  final _pickupTeamService = PickupTeamService();
  final _branchService = BranchService();

  List<Branch> branches = [];
  Branch? selectedBranch;
  List<dynamic> pickupPersons = [];
  List<int> selectedPickupPersons = [];

  @override
  void initState() {
    super.initState();
    fetchBranches();
    if (widget.pickup != null) {
      _nameController.text = widget.pickup!['name'] ?? '';
      selectedPickupPersons = List<int>.from(widget.pickup!['user_id'] ?? []);
    }
  }

  Future<void> fetchBranches() async {
    final data = await _branchService.getBranches();

    setState(() {
      branches = data;

      if (widget.pickup != null) {
        final branchId = widget.pickup!['branch'];
        selectedBranch = branches.firstWhere(
          (branch) => branch.id == branchId,
          orElse: () => branches.first,
        );
      } else {
        selectedBranch = branches.first;
      }
    });

    if (selectedBranch != null) {
      await fetchPickupPersons(
        pickupTeamId: widget.pickup?['id'],
        branchId: selectedBranch!.id!,
      );
    }
  }

  Future<void> fetchPickupPersons({
    int? pickupTeamId,
    required int branchId,
  }) async {
    final persons = await _pickupTeamService.getPickupPersons(
      pickupTeamId: pickupTeamId,
      branchID: branchId,
    );

    setState(() {
      pickupPersons = persons;
    });
  }

  void savePickupTeam() async {
    if (selectedBranch == null || selectedPickupPersons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Please select a branch and at least one pickup person",
          ),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final Map<String, dynamic> pickup = {
      'name': _nameController.text.trim(),
      'branch': selectedBranch?.id,
      'userId': selectedPickupPersons,
    };

    final navigator = Navigator.of(context);

    if (widget.pickup == null) {
      await _pickupTeamService.addPickupTeam(pickup);
    } else {
      await _pickupTeamService.updatePickupTeam(widget.pickup!['id'], pickup);
    }

    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: Navbar(
        title:
            widget.pickup == null ? "Create Pickup Team" : "Edit Pickup Team",
        backButton: true,
      ),
      extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Branch Master"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          SafeArea(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Input(
                              placeholder: "Name",
                              controller: _nameController,
                              validator: (value) {
                                final validator = Validator(
                                  validators: [const RequiredValidator()],
                                );
                                return validator.validate(
                                  label: 'Name',
                                  value: value,
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            CustomDropdown<Branch>(
                              label: 'Select Branch',
                              items: branches,
                              selectedItem: selectedBranch,
                              onChanged: (Branch? value) async {
                                if (value != null) {
                                  setState(() => selectedBranch = value);
                                  await fetchPickupPersons(
                                    pickupTeamId:
                                        widget
                                            .pickup?['id'], // pass pickupTeamId if available
                                    branchId: value.id!,
                                  );
                                }
                              },
                              getLabel: (Branch br) => br.name,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children:
                                  pickupPersons.map((person) {
                                    final id = person['id'];
                                    final name = person['name'];
                                    return FilterChip(
                                      label: Text(name),
                                      selected: selectedPickupPersons.contains(
                                        id,
                                      ),
                                      onSelected: (isSelected) {
                                        setState(() {
                                          isSelected
                                              ? selectedPickupPersons.add(id)
                                              : selectedPickupPersons.remove(
                                                id,
                                              );
                                        });
                                      },
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                StretchableButton(
                                  onPressed: savePickupTeam,
                                  children: const [
                                    Icon(Icons.save, color: colorWhite),
                                    SizedBox(width: 8),
                                    Text(
                                      "Submit",
                                      style: TextStyle(color: colorWhite),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
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
