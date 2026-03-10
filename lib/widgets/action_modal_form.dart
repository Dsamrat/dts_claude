import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActionModalForm extends StatefulWidget {
  final String? initialActionType;
  final String? initialReason;
  final DateTime? initialDateTime;
  final int? invoiceCurrentStatus;
  final String? expressFlag;
  // final Function(String?, String?, String?) onSubmit; // Date as String
  final void Function(String?, String?, String?, bool) onSubmit;

  const ActionModalForm({
    this.initialActionType,
    this.initialReason,
    this.initialDateTime,
    this.invoiceCurrentStatus,
    this.expressFlag,
    required this.onSubmit,
    super.key,
  });

  @override
  State<ActionModalForm> createState() => _ActionModalFormState();
}

class _ActionModalFormState extends State<ActionModalForm> {
  final _formKey = GlobalKey<FormState>();
  /*actionType refers to the current selection
  widget.initialActionType refers to the old selection*/
  String? actionType;
  String? reason;
  String? selectedDateTime; // Store as String
  final TextEditingController _dateTimeController = TextEditingController();

  List<String> get actionOptions {
    if (widget.initialActionType == "Hold" ||
        widget.initialActionType == "Reschedule") {
      return ["Hold", "Unhold", "Cancel", "Reschedule"];
    } else if (widget.initialActionType == "Cancel") {
      return ["Cancel"];
    } else {
      return ["Hold", "Cancel", "Reschedule"];
    }
  }

  final allReasons = [
    'customer\'s request',
    'Courier Delivery',
    'Customer Collected',
    'City Invoices',
    'Other Region (RAK)',
    'Other Region (AAN)',
    'Other Region (FJR)',
    'Other Region (UAQ)',
    'Payment Delay By Customer',
    'Less Value (Remote Location)',
    'Customer Break',
    'Delay Due To Adverse Weather',
    'Customer Closed',
    'Customer Location Changed',
    'Ramadan Time',
    'Midday Break',
    'SO ageing',
  ];
  List<String> get reasonOptions {
    if (widget.initialActionType == "Cancel") {
      return [widget.initialReason!];
    } else {
      return allReasons;
    }
  }

  @override
  void initState() {
    super.initState();
    actionType = widget.initialActionType;
    // reason = widget.initialReason ?? reasonOptions.first;
    reason = widget.initialReason;
    debugPrint('test${widget.initialDateTime}');
    if (widget.initialDateTime != null) {
      selectedDateTime = widget.initialDateTime!.toIso8601String();
      // Format the initial date and set it to the controller
      _dateTimeController.text = DateFormat(
        'dd/MM/yyyy h:mm a',
      ).format(widget.initialDateTime!);
      debugPrint(
        DateFormat('dd/MM/yyyy h:mm a').format(widget.initialDateTime!),
      );
    }
  }

  @override
  void dispose() {
    _dateTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    // Step 1: Date picker
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null) return;

    // Step 2: Time picker
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 1))),
    );
    if (time == null) return;

    // Step 3: Combine date & time
    final dt = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      selectedDateTime = dt.toIso8601String();
      _dateTimeController.text = DateFormat('dd/MM/yyyy h:mm a').format(dt);
    });
  }

  void _submitForm({bool confirmed = false}) {
    if (_formKey.currentState!.validate()) {
      widget.onSubmit(actionType, reason, selectedDateTime, confirmed);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Update Status"),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: actionOptions.contains(actionType) ? actionType : null,
              decoration: const InputDecoration(labelText: "Action Type"),
              items:
                  actionOptions
                      .map(
                        (val) => DropdownMenuItem(value: val, child: Text(val)),
                      )
                      .toList(),
              onChanged: (val) {
                setState(() {
                  actionType = val;
                  if (val != "Reschedule") {
                    selectedDateTime = null;
                    _dateTimeController.clear();
                  }
                  if (val == "Unhold") {
                    selectedDateTime = null;
                    _dateTimeController.clear();
                    reason = null;
                  }
                });
              },
              validator:
                  (val) => val == null ? "Please select action type" : null,
            ),
            const SizedBox(height: 10),
            if (actionType != "Unhold") ...[
              DropdownButtonFormField<String>(
                value:
                    reason != null && reasonOptions.contains(reason)
                        ? reason
                        : null,
                decoration: const InputDecoration(labelText: "Reason"),
                items:
                    reasonOptions
                        .map(
                          (val) =>
                              DropdownMenuItem(value: val, child: Text(val)),
                        )
                        .toList(),
                onChanged: (val) => setState(() => reason = val),
                validator:
                    (val) =>
                        (val == null && actionType != 'Unhold')
                            ? "Please select reason"
                            : null,
              ),
            ],
            if (actionType == "Reschedule") ...[
              const SizedBox(height: 10),
              TextFormField(
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Select Date & Time",
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                controller: _dateTimeController,
                onTap: _pickDateTime,
                validator: (val) {
                  if (actionType == "Reschedule") {
                    if (val != null && val.isNotEmpty) {
                      if (selectedDateTime != null &&
                          DateTime.parse(
                            selectedDateTime!,
                          ).isBefore(DateTime.now())) {
                        return "Please select a future date & time";
                      }
                    }
                  }
                  return null;
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        if (actionType != "Cancel" || widget.initialActionType != "Cancel")
          //ElevatedButton(onPressed: _submitForm, child: const Text("Submit")),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                if (widget.invoiceCurrentStatus != null &&
                    widget.invoiceCurrentStatus! == 5 &&
                    widget.expressFlag != 'exp' &&
                    widget.initialActionType != "Hold" &&
                    widget.initialActionType != "Reschedule") {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: const Text("Confirmation"),
                          content: RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                              ),
                              children: [
                                const TextSpan(
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 18,
                                  ),
                                  text: "Is the invoice offloaded?\n\n",
                                ),
                                const TextSpan(
                                  text: "Note:",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text:
                                      "If you confirm, invoice will be removed from the trip",
                                ),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pop(false); // 👈 return false
                              },
                              child: const Text("No"),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pop(true); // 👈 return true
                              },
                              child: const Text("Yes"),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    _submitForm(confirmed: true);
                  } else if (confirm == false) {
                    _submitForm(confirmed: false); // 👈 handle No here
                  }
                } else {
                  _submitForm(confirmed: false);
                }
              }
            },
            child: const Text("Submit"),
          ),
      ],
    );
  }
}
