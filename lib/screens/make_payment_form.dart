import 'package:dts/screens/sales_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/common.dart';
import '../services/driver_service.dart';
import 'accounts_home_screen.dart';
import 'driver_home_screen.dart';

class MakePaymentForm extends StatefulWidget {
  final int invoiceId;
  final String docNum;
  final String invoiceAmount;
  // 👇 Optional initial values for editing
  final String? deliveryType;
  final String? salesType;
  final String? initialPaymentReceived;
  final String? initialPaymentMode;
  final String? initialChequeNumber;
  final String? initialAmount;
  final String? initialAmountOption;
  const MakePaymentForm({
    super.key,
    required this.invoiceId,
    required this.docNum,
    required this.invoiceAmount,
    this.deliveryType,
    this.salesType,
    this.initialPaymentReceived,
    this.initialPaymentMode,
    this.initialChequeNumber,
    this.initialAmount,
    this.initialAmountOption,
  });
  @override
  State<MakePaymentForm> createState() => _MakePaymentFormState();
}

class _MakePaymentFormState extends State<MakePaymentForm> {
  bool _isSubmitting = false;
  late TextEditingController amountController;
  late TextEditingController chequeController;
  // final TextEditingController receiptNumber = TextEditingController();
  final DriverService _driverService = DriverService();

  late String selectedAmountOption; // value will be set in initState()
  String? selectedPaymentReceived = 'Unpaid'; // default
  List<String> paymentReceivedOptions = [];
  // String selectedAmountOption = 'Current Invoice';
  late String selectedMode;
  late String selectedDocNum;
  int? currentUserId;
  int? currentDepartmentId;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController memoController = TextEditingController();

  List<String> existingNames = ['Accounts', 'CRM', 'Sales'];
  List<String> newNames = [];
  String? selectedName;
  bool addingNewName = false;
  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    selectedAmountOption = widget.initialAmountOption ?? 'Current Invoice';
    selectedMode = widget.initialPaymentMode ?? 'Cash';
    // await _fetchNames();

    await _loadUserDetails();
    selectedDocNum = widget.docNum.toString();
    // Initialize amountController based on selectedAmountOption
    _initializeAmountController();
  }

  void _setPaymentOptions() {
    if (currentDepartmentId == 7 ||
        currentDepartmentId == 8 ||
        currentDepartmentId == 10) {
      paymentReceivedOptions = ['Receive Payment', 'Not Paid']; /*, 'Unpaid'*/
    } else if (currentDepartmentId == 5) {
      paymentReceivedOptions = [
        'Receive Payment',
        /*'Unpaid',*/
        'Receive in Advance',
        'Proceed without payment',
      ];
    }

    // ✅ If editing, try to pre-select the previously chosen option
    if (widget.initialPaymentReceived != null &&
        paymentReceivedOptions.contains(widget.initialPaymentReceived)) {
      selectedPaymentReceived = widget.initialPaymentReceived!;
    } else {
      // Fallback to the first option if editing value not valid or null
      selectedPaymentReceived = paymentReceivedOptions.first;
    }
  }

  void _initializeAmountController() {
    // Format invoice amount safely
    final String amount =
        double.tryParse(widget.invoiceAmount ?? '0')?.toStringAsFixed(2) ??
        '0.00';

    // If editing and an initial value was provided, always use that
    if (widget.initialAmount != null && widget.initialAmount!.isNotEmpty) {
      final String initial_amount =
          double.tryParse(widget.initialAmount ?? '0')?.toStringAsFixed(2) ??
          '0.00';
      amountController = TextEditingController(text: initial_amount);
    }
    // If user selected "Current Invoice", use the invoice amount
    else if (selectedAmountOption == 'Current Invoice') {
      amountController = TextEditingController(text: amount);
    }
    // Otherwise leave blank for manual entry
    else {
      amountController = TextEditingController(text: '');
    }
    chequeController = TextEditingController(text: widget.initialChequeNumber);
  }

  Future<void> submitPayment() async {
    // Validate only if 'Yes' is selected for Payment Received
    if (selectedPaymentReceived == null ||
        selectedPaymentReceived == 'Unpaid') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid payment status')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });
      final memoToSubmit = memoController.text.trim();
      final nameToSubmit = nameController.text.trim();
      try {
        final payLoadData = {
          'invoice_id': widget.invoiceId,
          'payment_received': selectedPaymentReceived, // Include new field
          'select_amount_option': selectedAmountOption,
          'payment_mode': selectedMode,
          'amount': amountController.text,
          // 'receiptNumber': receiptNumber.text,
          'currentUserId': currentUserId!,
          'currentDepartmentId': currentDepartmentId!,
          'cheque_number': chequeController.text,
          'memo': memoToSubmit,
          'nameToSubmit': nameToSubmit,
        };
        // print(payLoadData);
        // return;
        await _driverService.markPaymentReceived(payloadData: payLoadData);
        if (currentDepartmentId == 7 || currentDepartmentId == 8) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            (route) => false,
          );
        }
        if (currentDepartmentId == 10) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SalesHomeScreen()),
            (route) => false,
          );
        }
        if (currentDepartmentId == 5) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AccountsHomeScreen()),
            (route) => false,
          );
        }
        // Success: Navigate to DriverHomeScreen and clear stack
      } catch (e) {
        debugPrint('Error: $e'); // Good for debugging
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update payment info: ${e.toString()}'),
          ), // Show specific error
        );
      } finally {
        setState(() {
          _isSubmitting = false; // Hide loader regardless of success/failure
        });
      }
    }
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getInt('userId');
      currentDepartmentId = prefs.getInt('departmentId');
      _setPaymentOptions();
    });
  }

  @override
  void dispose() {
    amountController.dispose();
    // receiptNumber.dispose();
    chequeController.dispose(); // Also dispose chequeController
    memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (currentDepartmentId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    bool requiresName =
        (selectedPaymentReceived == 'Proceed without payment' ||
            selectedPaymentReceived == 'Not Paid');
    // Determine available payment received options based on delivery type
    return Scaffold(
      appBar: AppBar(title: const Text('Make Payment')), // Use const for Text
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          // Wrap the Column with SingleChildScrollView
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch, // Helps buttons/fields fill width
              children: [
                Text(
                  '${widget.docNum}',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: secondaryTeal,
                  ),
                ),
                const SizedBox(height: 25),

                const Text(
                  'Payment Option',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: secondaryTeal,
                  ),
                ),
                // --- Radio Buttons ---
                ...paymentReceivedOptions.map((option) {
                  return RadioListTile<String>(
                    title: Text(option),
                    value: option,
                    groupValue: selectedPaymentReceived,
                    onChanged: (value) {
                      setState(() {
                        selectedPaymentReceived = value;
                        // Reset if "No" or "Unpaid" is selected
                        if (selectedPaymentReceived == 'Unpaid') {
                          selectedAmountOption = 'Current Invoice';
                          amountController.text =
                              double.tryParse(
                                widget.invoiceAmount ?? '0',
                              )?.toStringAsFixed(2) ??
                              '0.00';
                          selectedMode = 'Cash';
                          chequeController.clear();
                        }
                      });
                    },
                    // Reduce height and remove default horizontal padding
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
                // --- Payment Received Dropdown ---
                const SizedBox(height: 10),
                // --- Conditional fields based on Payment Received ---
                if (selectedPaymentReceived == 'Receive Payment') ...[
                  // --- Radio Buttons for Amount ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Amount Option:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Instead of a Row, use individual RadioListTiles directly in the Column
                      RadioListTile<String>(
                        title: const Text('Current Invoice'),
                        value: 'Current Invoice',
                        groupValue: selectedAmountOption,
                        onChanged: (value) {
                          setState(() {
                            selectedAmountOption = value!;
                            amountController.text =
                                double.tryParse(
                                  widget.invoiceAmount ?? '0',
                                )?.toStringAsFixed(2) ??
                                '0.00';
                            ;
                          });
                        },
                        // Reduce height and remove default horizontal padding
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      // Other Amount Radio Button
                      RadioListTile<String>(
                        title: const Text('Other Amount'),
                        value: 'Other Amount',
                        groupValue: selectedAmountOption,
                        onChanged: (value) {
                          setState(() {
                            selectedAmountOption = value!;
                            amountController.clear(); // Clear for other amount
                          });
                        },
                        // Reduce height and remove default horizontal padding
                        visualDensity: const VisualDensity(
                          horizontal: -4,
                          vertical: -4,
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextFormField(
                    controller: amountController,
                    keyboardType: TextInputType.number,

                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      labelStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: secondaryTeal,
                      ),
                      border: OutlineInputBorder(), // optional
                    ),
                    validator: (value) {
                      if (selectedPaymentReceived == 'Receive Payment') {
                        // Validate only if payment received
                        if (value == null || value.isEmpty) {
                          return 'Amount is required';
                        }
                        final number = num.tryParse(value);
                        if (number == null) {
                          return 'Enter a valid number';
                        }
                        if (number <= 0) {
                          return 'Amount must be greater than zero';
                        }
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // --- Mode of Payment Dropdown ---
                  DropdownButtonFormField<String>(
                    value: selectedMode,
                    items:
                        ['Cheque', 'Cash', 'Card', 'PBL', 'Bank Transfer']
                            .map(
                              (mode) => DropdownMenuItem(
                                value: mode,
                                child: Text(mode),
                              ),
                            )
                            .toList(),
                    onChanged:
                        (value) => setState(() {
                          selectedMode = value!;
                        }),
                    decoration: const InputDecoration(
                      labelText: 'Payment Mode',
                      labelStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: secondaryTeal,
                      ),
                    ),
                    validator: (value) {
                      if (selectedPaymentReceived == 'Receive Payment' &&
                          (value == null || value.isEmpty)) {
                        return 'Please select a payment mode';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // --- Cheque Number Text Field (Conditional) ---
                  if (selectedMode == 'Cheque')
                    TextFormField(
                      controller: chequeController,
                      decoration: const InputDecoration(
                        labelText: 'Cheque Number',
                        labelStyle: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: secondaryTeal,
                        ),
                        border: OutlineInputBorder(), // optional
                      ),
                      validator: (value) {
                        if (selectedPaymentReceived == 'Receive Payment' &&
                            selectedMode == 'Cheque' &&
                            (value == null || value.isEmpty)) {
                          return 'Enter cheque number';
                        }
                        return null;
                      },
                    ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: memoController,
                  decoration: const InputDecoration(
                    labelText: 'Memo',
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: secondaryTeal,
                    ),
                    border: OutlineInputBorder(), // optional
                  ),

                  keyboardType: TextInputType.multiline,
                  minLines: 2, // minimum number of visible lines
                  maxLines: 6, // maximum number of visible lines
                  validator: (value) {},
                ),
                if (selectedPaymentReceived == 'Proceed without payment' ||
                    selectedPaymentReceived == 'Not Paid') ...[
                  const SizedBox(height: 10),

                  const Text(
                    'Approved By:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: secondaryTeal,
                    ),
                  ),
                  const SizedBox(height: 1),
                  // Display all emails as chips
                  if (existingNames.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No Names(s) found',
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Wrap(
                        spacing: 2,
                        runSpacing: 0,
                        children:
                            existingNames.map((name) {
                              final bool isSelected =
                                  nameController.text == name;

                              return InputChip(
                                label: Text(
                                  name,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.teal.shade100,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                  vertical: 2,
                                ),

                                // Select / Unselect functionality
                                onPressed: () {
                                  setState(() {
                                    if (isSelected) {
                                      nameController.clear(); // unselect
                                    } else {
                                      nameController.text = name; // select
                                    }
                                  });
                                },
                              );
                            }).toList(),
                      ),
                    ),
                ],

                const SizedBox(height: 20),
                // --- Save Button ---
                ElevatedButton(
                  onPressed:
                      _isSubmitting
                          ? null
                          : () async {
                            // Step 3: Validate name
                            if (requiresName &&
                                nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Approved by is required."),
                                ),
                              );
                              return;
                            }

                            // Add your submit logic here
                            setState(() => _isSubmitting = true);
                            try {
                              await submitPayment(); // your async submit function
                            } finally {
                              if (mounted)
                                setState(() => _isSubmitting = false);
                            }
                          },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryTeal),
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
                          : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
