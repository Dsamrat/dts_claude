import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:signature/signature.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../constants/common.dart';
import '../services/driver_service.dart';
import '../widgets/pdf_widgets/web_pdf_viewer.dart';
import 'home_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../utils/file_utils.dart';
import 'package:open_filex/open_filex.dart';

class InvoiceSignOperation extends StatefulWidget {
  final int invoiceId;
  final int customerId;
  final int pdfId;
  final String resolvedDocNum;
  final String? signedPdfLink;
  final String pdfLink;

  const InvoiceSignOperation({
    Key? key,
    required this.invoiceId,
    required this.customerId,
    required this.pdfId,
    required this.resolvedDocNum,
    required this.pdfLink,
    this.signedPdfLink,
  }) : super(key: key);
  @override
  State<InvoiceSignOperation> createState() => _InvoiceSignOperationState();
}

class _InvoiceSignOperationState extends State<InvoiceSignOperation> {
  String? localPath;
  bool isLoading = true;
  bool _isSubmitting = false;
  bool isProcessing = false;
  String _iframeKey = DateTime.now().millisecondsSinceEpoch.toString();
  int? currentUserId;
  int? currentDepartmentId;

  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  // === Email & Name State ===
  final _formKey = GlobalKey<FormState>();
  List<String> existingEmails = [];
  List<String> newEmails = [];
  String? selectedEmail;
  bool addingNewEmail = false;
  final TextEditingController newEmailController = TextEditingController();

  // List<String> cachedNames = [];
  // String? selectedName;
  List<String> existingNames = [];
  List<String> newNames = [];
  Map<String, String> nameContactMap = {}; // name -> contact
  String? selectedName;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();

  final DriverService _driverService = DriverService();

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
    _fetchEmails();
    _fetchNames();
    loadPDF();
  }

  @override
  void dispose() {
    _controller.dispose();
    newEmailController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmails() async {
    try {
      final emailList = await _driverService.fetchEmails(widget.customerId);
      setState(() {
        existingEmails = emailList.map<String>((e) => e.toString()).toList();
      });
    } catch (e) {
      debugPrint('Error fetching emails: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanMsg)));
      }
    }
  }

  Future<void> _fetchNames() async {
    try {
      final response = await _driverService.fetchNames(widget.customerId);
      setState(() {
        nameContactMap = {
          for (var item in response)
            item['name']: item['contact_num']?.toString() ?? '',
        };
        existingNames = nameContactMap.keys.toList();
      });
    } catch (e) {
      debugPrint('Error fetching names: $e');
      if (mounted) {
        final cleanMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(cleanMsg)));
      }
    }
  }

  Future<void> _loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      currentUserId = prefs.getInt('userId');
      currentDepartmentId = prefs.getInt('departmentId');
    });
  }

  Future<void> loadPDF() async {
    if (kIsWeb) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http.get(Uri.parse(widget.pdfLink));
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/temp_invoice_${widget.resolvedDocNum}.pdf',
      );
      await file.writeAsBytes(response.bodyBytes);
      setState(() {
        localPath = file.path;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Failed to load PDF: $e');
      setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _submitSignature() async {
    if (_controller.isEmpty) {
      _showSnackBar('Please provide a signature before submitting.');
      return;
    }

    if (!mounted) return;
    setState(() => _isSubmitting = true);

    try {
      if (!mounted) return;
      if (!_formKey.currentState!.validate()) return;

      // Or if you only want to send the selected email(s):
      final uniqueEmails = newEmails.toSet().toList(); // Remo
      final nameToSubmit = nameController.text.trim();
      final contactSubmit = contactController.text.trim();

      String textToPrint = '';
      if (nameToSubmit.isNotEmpty && contactSubmit.isNotEmpty) {
        textToPrint = '$nameToSubmit ($contactSubmit)';
      } else if (nameToSubmit.isNotEmpty) {
        textToPrint = nameToSubmit;
      } else if (contactSubmit.isNotEmpty) {
        textToPrint = contactSubmit;
      }

      setState(() => _isSubmitting = true);

      // Get signature
      final Uint8List? signatureBytes = await _controller.toPngBytes();
      if (signatureBytes == null) {
        if (!mounted) return;
        _showSnackBar('Failed to capture signature.');
        return;
      }
      /*READ PDF DOCUMENT*/
      final file = File(localPath!);
      final PdfDocument document = PdfDocument(
        inputBytes: await file.readAsBytes(),
      );
      // 1️⃣ Find "Receiver's Name"
      List<MatchedItem> nameMatches = PdfTextExtractor(
        document,
      ).findText(['Receiver\'s Name']);
      if (nameMatches.isEmpty) {
        debugPrint("⚠️ 'Receiver's Name' not found in PDF");
        document.dispose();
        return;
      }
      final MatchedItem nameMatch = nameMatches.first;
      final Rect nameBounds = nameMatch.bounds;
      // 2️⃣ Find "Receiver Signature"
      List<MatchedItem> signatureMatches = PdfTextExtractor(document).findText([
        "Receiver Signature", // without apostrophe
        "Receiver's Signature", // with apostrophe
      ]);

      if (signatureMatches.isEmpty) {
        debugPrint("⚠️ 'Receiver Signature' not found in PDF");
        document.dispose();
        return;
      }
      final MatchedItem signatureMatch = signatureMatches.first;
      final Rect signatureBounds = signatureMatch.bounds;
      // 3️⃣ Draw the submitted name near "Receiver's Name"
      document.pages[nameMatch.pageIndex].graphics.drawString(
        textToPrint,
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: Rect.fromLTWH(
          nameBounds.right + 10, // right side of "Receiver's Name"
          nameBounds.top - 2, // adjust vertical alignment
          200, // width for the name text
          20, // height for the name text
        ),
      );
      // 4️⃣ Draw the signature image near "Receiver Signature"
      final PdfBitmap signatureImage = PdfBitmap(signatureBytes);
      // Draw the signature near "Receiver Signature"
      final double sigX = signatureBounds.right + 60;
      final double sigY = signatureBounds.top - 5;
      final double sigWidth = 120;
      final double sigHeight = 40;
      document.pages[signatureMatch.pageIndex].graphics.drawImage(
        signatureImage,
        Rect.fromLTWH(sigX, sigY, sigWidth, sigHeight),
      );
      // 1️⃣ Get current date (or any custom date)
      final String dateTimeText = DateFormat(
        'dd-MM-yyyy hh:mm a',
      ).format(DateTime.now());

      // 2️⃣ Draw date below the signature
      document.pages[signatureMatch.pageIndex].graphics.drawString(
        dateTimeText,
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        bounds: Rect.fromLTWH(
          sigX,
          sigY + sigHeight + 5, // below signature
          sigWidth,
          15,
        ),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      final dir = await getApplicationDocumentsDirectory();
      final signedFile = File('${dir.path}/signed_invoice.pdf');
      await signedFile.writeAsBytes(bytes, flush: true);
      // Convert signature image to base64
      final base64Signature = base64Encode(signatureBytes);
      // Read file as bytes
      final Uint8List pdfBytes = await signedFile.readAsBytes();
      // Convert PDF to base64
      final String base64Pdf = base64Encode(pdfBytes);
      // Default lat/lng as empty strings
      String latitude = '';
      String longitude = '';
      /*GET USER LOCATION*/
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied.');
      }
      // Try to get location, but don't stop if it fails
      try {
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
      } catch (e) {
        debugPrint('⚠️ Failed to get location: $e');
        // Proceed with empty lat/lng
      }

      // Build payload
      final payloadData = {
        'pdfId': widget.pdfId,
        'invoiceId': widget.invoiceId,
        'nameToSubmit': nameToSubmit,
        "contact": contactController.text.trim(),
        // "issue": selectedIssue,
        'customerId': widget.customerId,
        'latitude': latitude,
        'longitude': longitude,
        'currentUserId': currentUserId,
        'currentDepartmentId': currentDepartmentId,
        'uniqueEmails': uniqueEmails,
        'base64Signature': base64Signature,
        'signedDoc': base64Pdf,
      };
      final message = await _driverService.uploadSignatureOperation(
        payloadData: payloadData,
      );
      if (!mounted) return;
      _showSnackBar(message);
      _controller.clear();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error uploading signature.');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Combine and deduplicate all emails before building dropdown
    final allEmails = {...existingEmails, ...newEmails}.toList();
    final allNames = {...existingNames, ...newNames}.toList();
    final pdfUrl =
        widget.signedPdfLink?.isNotEmpty == true
            ? widget.signedPdfLink
            : widget.pdfLink;
    final docTitle = widget.resolvedDocNum ?? 'Invoice';
    return Scaffold(
      // appBar: Navbar(title: "Sign ${widget.resolvedDocNum}", backButton: true),
      appBar: AppBar(
        title: Tooltip(
          message: docTitle,
          child: Text(
            "Sign ${widget.resolvedDocNum}",
            overflow: TextOverflow.ellipsis,
          ),
        ),
        backgroundColor: secondaryTeal,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (pdfUrl != null &&
              pdfUrl.isNotEmpty &&
              !kIsWeb) // adjust condition if needed
            PopupMenuButton<String>(
              icon:
                  isProcessing
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.more_vert),
              onSelected: (value) async {
                setState(() => isProcessing = true);
                final fileName = '${widget.resolvedDocNum}.pdf';
                final pdfType =
                    (widget.signedPdfLink?.isNotEmpty == true)
                        ? 'signed'
                        : 'unsigned';

                try {
                  if (value == 'share') {
                    FileUtils.showToast('Preparing to share $pdfType PDF...');
                    final path = await FileUtils.downloadPdf(
                      pdfUrl,
                      fileName,
                      showToast: false,
                    );
                    if (path != null && await File(path).exists()) {
                      await FileUtils.sharePdf(path);
                      FileUtils.showToast('Shared successfully!');
                    } else {
                      FileUtils.showToast('PDF file not found to share');
                    }
                  } else if (value == 'download') {
                    final path = await FileUtils.downloadPdf(pdfUrl, fileName);
                    if (path != null) await OpenFilex.open(path);
                  }
                } catch (e) {
                  FileUtils.showToast('Failed: $e');
                } finally {
                  setState(() => isProcessing = false);
                }
              },
              itemBuilder:
                  (_) => [
                    PopupMenuItem(
                      value: 'share',
                      child: ListTile(
                        leading: const Icon(Icons.share),
                        title: Text('Share'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'download',
                      child: ListTile(
                        leading: const Icon(Icons.download),
                        title: Text('Download'),
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              if (widget.signedPdfLink?.trim().isEmpty ?? true) {
                await _fetchEmails();
                await _fetchNames();
              }
            },

            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height:
                        (widget.signedPdfLink == null ||
                                widget.signedPdfLink!.trim().isEmpty)
                            ? 500
                            : 700,
                    child: Container(
                      color: Colors.grey[300],
                      child:
                          isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : kIsWeb
                              ? WebPdfViewer(
                                pdfUrl: widget.pdfLink,
                                key: ValueKey(_iframeKey),
                              )
                              : localPath != null
                              ? PDFView(
                                filePath: localPath!,
                                fitEachPage: true,
                                fitPolicy: FitPolicy.BOTH,
                              )
                              : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Failed to load PDF.'),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: () {
                                        setState(() => isLoading = true);
                                        if (kIsWeb) {
                                          _iframeKey =
                                              DateTime.now()
                                                  .millisecondsSinceEpoch
                                                  .toString();
                                        } else {
                                          loadPDF();
                                        }
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ),
                  // Signature Section (only show if conditions are met)
                  if ((widget.signedPdfLink?.trim().isEmpty ?? true))
                    Form(
                      key: _formKey,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Email(s):'),
                            const SizedBox(height: 1),
                            // Display all emails as chips
                            if (existingEmails.isEmpty && newEmails.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'No email(s) found',
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
                                      allEmails
                                          .map(
                                            (e) => Chip(
                                              label: Text(
                                                e,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 1,
                                                    vertical: 2,
                                                  ),
                                              deleteIcon: const Icon(
                                                Icons.close,
                                                size: 16,
                                              ),
                                              onDeleted:
                                                  newEmails.contains(e)
                                                      ? () {
                                                        setState(
                                                          () => newEmails
                                                              .remove(e),
                                                        );
                                                      }
                                                      : null,
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            // const SizedBox(height: 20),

                            // TextField to add new email
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: newEmailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Add new email',
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    final email =
                                        newEmailController.text.trim();
                                    final error = _validateEmail(email);

                                    if (error != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      if (!existingEmails.contains(email) &&
                                          !newEmails.contains(email)) {
                                        newEmails.add(email);
                                      }
                                      selectedEmail = email;
                                      addingNewEmail = false;
                                      newEmailController.clear();
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Divider(thickness: 1),
                            const SizedBox(height: 4),

                            const Text('Received By:'),
                            const SizedBox(height: 1),
                            // Display all emails as chips
                            if (existingNames.isEmpty && newNames.isEmpty)
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
                                      allNames.map((name) {
                                        final bool isSelected =
                                            nameController.text == name;

                                        return InputChip(
                                          label: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
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
                                                nameController
                                                    .clear(); // unselect
                                                contactController.clear();
                                              } else {
                                                nameController.text =
                                                    name; // select
                                                contactController.text =
                                                    nameContactMap[name] ?? '';
                                              }
                                            });
                                          },

                                          // Delete icon for newly added names only
                                          deleteIcon:
                                              newNames.contains(name)
                                                  ? const Icon(
                                                    Icons.close,
                                                    size: 16,
                                                  )
                                                  : null,

                                          onDeleted:
                                              newNames.contains(name)
                                                  ? () {
                                                    setState(() {
                                                      newNames.remove(name);
                                                      if (nameController.text ==
                                                          name) {
                                                        nameController.clear();
                                                        contactController
                                                            .clear();
                                                      }
                                                    });
                                                  }
                                                  : null,
                                        );
                                      }).toList(),
                                ),
                              ),
                            // TextField to add new email
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Add new name',
                                    ),
                                    onChanged: (val) {
                                      contactController.text =
                                          ''; // reset contact for new name
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    final name = nameController.text.trim();
                                    final error = _validateName(name);

                                    if (error != null) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(error)),
                                      );
                                      return;
                                    }

                                    setState(() {
                                      // Add only if not already present
                                      if (!existingNames.contains(name) &&
                                          !newNames.contains(name)) {
                                        newNames.add(name);
                                      }

                                      // ✔ Auto-select the newly added name
                                      nameController.text = name;
                                      contactController.text = '';

                                      // ❌ Do not clear it (we want it selected)
                                      // nameController.clear();  <-- REMOVE THIS
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Contact number
                            TextField(
                              controller: contactController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Contact Number',
                              ),
                            ),

                            const SizedBox(height: 4),
                            const Divider(thickness: 1),
                            const SizedBox(height: 4),

                            const SizedBox(height: 20),

                            const Text(
                              "Customer Signature",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            Signature(
                              controller: _controller,
                              height: 200,
                              backgroundColor: Colors.grey[200]!,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : () => _controller.clear(),
                                  child: const Text("Clear"),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      _isSubmitting
                                          ? null
                                          : () async {
                                            // Step 1: Validate signature
                                            if (_controller.isEmpty) {
                                              _showSnackBar(
                                                "Customer signature is required.",
                                              );
                                              return;
                                            }
                                            // Step 2: Validate at least one email
                                            if (existingEmails.isEmpty &&
                                                newEmails.isEmpty) {
                                              _showSnackBar(
                                                "At least one email is required.",
                                              );
                                              return;
                                            }
                                            // Step 3: Validate name
                                            if (nameController.text
                                                .trim()
                                                .isEmpty) {
                                              _showSnackBar(
                                                "Received by name is required.",
                                              );
                                              return;
                                            }
                                            if (contactController.text
                                                .trim()
                                                .isEmpty) {
                                              _showSnackBar(
                                                "Received by contact number is required.",
                                              );
                                              return;
                                            }

                                            // Submit in all cases if signature is valid
                                            _submitSignature();
                                          },

                                  child:
                                      _isSubmitting
                                          ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : const Text("Submit"),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // === Full-screen loader overlay ===
          if (_isSubmitting)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) {
      return "Email cannot be empty";
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email.trim())) {
      return "Please enter a valid email";
    }
    return null;
  }

  String? _validateName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return "Name cannot be empty";
    }

    return null;
  }
}
