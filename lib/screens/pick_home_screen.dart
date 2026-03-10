import 'package:dts/constants/common.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/PdfDetail.dart';
import '../services/pusher_service.dart';
import '../widgets/background_allscreen.dart';
import '../widgets/build_invoice_card.dart';
import '../widgets/drawer.dart';
import 'home_screen.dart';

import '../services/pickup_invoice_service.dart';

import '../utils/pusher_connector_interface.dart' as connector_interface;
import '../utils/pusher_connector_stub_impl.dart'
    if (dart.library.js) '../utils/pusher_connector_web_impl.dart'
    if (dart.library.io) '../utils/pusher_connector_stub_impl.dart'
    as connector_impl;

class PickHomeScreen extends StatefulWidget {
  const PickHomeScreen({super.key});

  @override
  State<PickHomeScreen> createState() => _PickHomeScreenState();
}

class _PickHomeScreenState extends State<PickHomeScreen>
    with SingleTickerProviderStateMixin {
  Set<int> _loadingItemIds = {};
  late TabController _tabController;
  final PickupInvoiceService _pickupInvoiceService = PickupInvoiceService();
  List<PickupInvoiceWithItems> invoicesWithItems = [];
  bool isLoading = false;

  int? isPickupTeam;
  int? currentUserBranchId;
  int? isMultiBranch;
  int? userBranchId;
  int? userId;
  int currentPage = 1;
  final List<bool> _expandedInvoices = []; // Initialize in initState
  List<ItemWithInvoice> allItems = []; // Initialize in initState

  final Map<String, List<InvoiceQuantity>> _groupedItems = {};
  final List<bool> _expandedGroupedItems = [];

  late final connector_interface.IPusherConnector _pusherConnector;
  bool _pusherInitialized = false;

  @override
  void initState() {
    super.initState();
    _pusherConnector = connector_impl.createPusherConnector();
    _initialize(); // ✅ call async function without await
  }

  Future<void> _initialize() async {
    _tabController = TabController(length: 2, vsync: this);

    await loadUserDetails();
    // await Future.wait([_fetchData(), _initPusher()]);
    await _fetchData();
    if (kIsWeb && !_pusherInitialized) {
      _initializePusherWeb();
      _pusherInitialized = true;
    } else if (!kIsWeb) {
      await _initPusher();
    }
  }

  void _initializePusherWeb() {
    final channelNameWeb = 'pickup-$currentUserBranchId';
    const String eventNameWeb = 'pickup.created'; // Example dynamic value

    _pusherConnector.initPusherWeb(
      channelNameWeb,
      eventNameWeb,
      (raw) => _handlePusherEventWeb(raw), // call async inside sync wrapper
    );
  }

  Future<void> _handlePusherEventWeb(dynamic raw) async {
    try {
      await _fetchData();
    } catch (e, st) {
      debugPrint("❌ Error in _handlePusherEventWeb: $e");
      debugPrint("$st");
    }
  }

  Future<void> _initPusher() async {
    final pusherService = PusherService(
      apiKey: pusherAPIKey,
      cluster: pusherCluster,
      authEndpoint: pusherAuthURl,
      userToken: 'strinmg',
    );

    final channelName = 'pickup-$currentUserBranchId';
    debugPrint("📡 Subscribing to Pusher channel: $channelName");

    // ✅ Async callback for Pusher event
    pusherService.on(channelName, 'pickup.created', (data) async {
      debugPrint("Pickup created event received: $data");
      await _fetchData();
    });

    await pusherService.init();
  }

  Future<void> _fetchData() async {
    setState(() => isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      userBranchId = prefs.getInt('branchId');
      userId = prefs.getInt('userId');
      final fetchedInvoices = await _pickupInvoiceService.getPickupTeamInvoice(
        page: currentPage,
        userBranchId: userBranchId,
        userId: userId,
      );
      debugPrint('Fetched Invoices Raw: $fetchedInvoices');
      setState(() {
        invoicesWithItems = fetchedInvoices;
        _expandedInvoices.clear();
        _expandedInvoices.addAll(
          List.generate(invoicesWithItems.length, (index) => false),
        );
        _groupedItems.clear();
        for (var invoice in invoicesWithItems) {
          for (var item in invoice.items) {
            final itemKey = '${item.name}~${item.sku}~${item.sno}';
            if (!_groupedItems.containsKey(itemKey)) {
              _groupedItems[itemKey] = [];
            }
            _groupedItems[itemKey]!.add(
              InvoiceQuantity(
                invoiceNum: invoice.invoiceNum,
                customerName: invoice.customerName ?? '',
                qty: item.qty,
                unit: item.unit,
              ),
            );
          }
        }
        _expandedGroupedItems.clear();
        _expandedGroupedItems.addAll(
          List.generate(_groupedItems.length, (index) => false),
        );
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      print('Error fetching data: $e');
    }
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    isPickupTeam = prefs.getInt('isPickupTeam');
    currentUserBranchId = prefs.getInt('branchId');
    if (isPickupTeam == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      });
      return;
    }
  }

  void _toggleGroupedItemExpansion(int index) {
    setState(() {
      _expandedGroupedItems[index] = !_expandedGroupedItems[index];
    });
  }

  void _toggleInvoiceExpansion(int index) {
    setState(() {
      _expandedInvoices[index] = !_expandedInvoices[index];
    });
  }

  void _updateItemPickedStatusLocally(
    String invoiceNum,
    int itemId,
    bool newValue,
  ) {
    if (mounted) {
      setState(() {
        for (int i = 0; i < invoicesWithItems.length; i++) {
          if (invoicesWithItems[i].invoiceNum == invoiceNum) {
            final invoice = invoicesWithItems[i];
            final itemIndex = invoice.items.indexWhere(
              (item) => item.itemId == itemId,
            );
            if (itemIndex != -1) {
              final updatedItems = List<Item>.from(invoice.items);
              updatedItems[itemIndex] = updatedItems[itemIndex].copyWith(
                itemPicked: newValue ? 1 : 0,
              );
              invoicesWithItems[i] = invoice.copyWith(items: updatedItems);
              break;
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deliveries'),
        backgroundColor: primaryTeal,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'View by Invoice'), Tab(text: 'View by Item')],
          labelColor: colorWhite,
        ),
      ),
      extendBodyBehindAppBar: true,
      drawer: ArgonDrawer(currentPage: "Deliveries"),
      body: Stack(
        children: [
          backgroundAllScreen(),
          Positioned.fill(
            child:
                isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : invoicesWithItems.isEmpty
                    ? const Center(
                      child: Text(
                        "No records found",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                    : Column(
                      children: [
                        if (isLoading) const LinearProgressIndicator(),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              RefreshIndicator(
                                onRefresh: _fetchData,
                                color: Colors.white, // spinner color
                                backgroundColor:
                                    Colors.blue, // circle background
                                strokeWidth: 3,
                                child: _buildInvoiceView(
                                  invoicesWithItems,
                                  _expandedInvoices,
                                  _toggleInvoiceExpansion,
                                  _pickupInvoiceService,
                                  _updateItemPickedStatusLocally,
                                  _loadingItemIds,
                                  (int itemId, bool isLoading) {
                                    setState(() {
                                      if (isLoading) {
                                        _loadingItemIds.add(itemId);
                                      } else {
                                        _loadingItemIds.remove(itemId);
                                      }
                                    });
                                  },
                                ),
                              ),

                              RefreshIndicator(
                                onRefresh: _fetchData,
                                color: Colors.white, // spinner color
                                backgroundColor:
                                    Colors.blue, // circle background
                                strokeWidth: 3,
                                child: _buildItemWiseView(
                                  _groupedItems.keys.toList(),
                                  _groupedItems,
                                  _expandedGroupedItems,
                                  _toggleGroupedItemExpansion,
                                  _pickupInvoiceService,
                                  invoicesWithItems,
                                  // _toggleGroupedItemPicked,
                                  _updateItemPickedStatusLocally,
                                  _loadingItemIds,
                                  (int itemId, bool isLoading) {
                                    setState(() {
                                      if (isLoading) {
                                        _loadingItemIds.add(itemId);
                                      } else {
                                        _loadingItemIds.remove(itemId);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
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

class InvoiceQuantity {
  final String invoiceNum;
  final String customerName;
  final String? unit;
  final int qty;

  InvoiceQuantity({
    required this.invoiceNum,
    required this.customerName,
    required this.qty,
    this.unit,
  });
}

// Modify _buildInvoiceView function signature
Widget _buildInvoiceView(
  List<PickupInvoiceWithItems> invoices,
  List<bool> expandedStates,
  void Function(int) onToggle,
  PickupInvoiceService pickupInvoiceService,
  // Change parameter type from int invoiceId to String invoiceNum
  void Function(String, int, bool) onItemPickedChanged,
  Set<int> loadingItemIds,
  void Function(int itemId, bool isLoading) onLoadingChange,
) {
  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    controller: ScrollController(),
    itemCount: invoices.length,
    itemBuilder: (context, index) {
      final invoice = invoices[index];

      final isDisabled = isInvoiceDisabled(
        invoice.invoiceCurrentStatus,
        invoice.holdStatus,
        'test',
      );
      final paymentReceived = paymentReceivedForCOD(
        invoice.deliveryType,
        invoice.pmtReceived,
        invoice.codFlag,
      );
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice Card (no Card wrapping inside)
              buildInvoiceCard(
                invoice,
                context,
                screen: 'pickHomeScreen',
                onTap: () => onToggle(index),
                onToggleSignOnly: null,
                signUpdating: {},
                wrapWithCard: false,
                isExpanded: expandedStates[index],
              ),

              // Expanded content inside same container
              if (expandedStates[index]) ...[
                const Divider(height: 1),
                Container(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item Details:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: invoice.items.length,
                          itemBuilder: (itemContext, itemIndex) {
                            final item = invoice.items[itemIndex];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name),
                                        Text.rich(
                                          TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: 'Item Code: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(text: '${item.sku}'),
                                              TextSpan(
                                                text: ', Qty: ',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    '${item.qty} ${item.unit}',
                                              ),
                                            ],
                                            // Optional default style
                                          ),
                                        ),

                                        Text(
                                          item.sno,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  (loadingItemIds.contains(item.itemId))
                                      ? SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : Checkbox(
                                        value: item.itemPicked == 1,
                                        onChanged:
                                            (isDisabled || !paymentReceived)
                                                ? null // 👈 Disable checkbox
                                                : (bool? value) {
                                                  if (value != null) {
                                                    onLoadingChange(
                                                      item.itemId,
                                                      true,
                                                    );

                                                    pickupInvoiceService
                                                        .updateItemPickedStatus(
                                                          invoice.id,
                                                          item.itemId,
                                                          value,
                                                          invoice
                                                              .invoiceBranchId,
                                                          invoice.invoiceNum,
                                                        )
                                                        .then((
                                                          bool allItemsPicked,
                                                        ) {
                                                          onItemPickedChanged(
                                                            invoice.invoiceNum,
                                                            item.itemId,
                                                            value,
                                                          );

                                                          if (allItemsPicked) {
                                                            Navigator.pushReplacement(
                                                              context,
                                                              MaterialPageRoute(
                                                                builder:
                                                                    (_) =>
                                                                        const PickHomeScreen(),
                                                              ),
                                                            );
                                                          }
                                                        })
                                                        .catchError((error) {
                                                          debugPrint('$error');
                                                          // 👇 Rollback to previous state
                                                          onItemPickedChanged(
                                                            invoice.invoiceNum,
                                                            item.itemId,
                                                            !value,
                                                          );

                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                '${error.toString()}',
                                                              ),
                                                            ),
                                                          );
                                                        })
                                                        .whenComplete(() {
                                                          onLoadingChange(
                                                            item.itemId,
                                                            false,
                                                          );
                                                        });
                                                  }
                                                },
                                      ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8.0),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildItemWiseView(
  List<String> uniqueItemKeys,
  Map<String, List<InvoiceQuantity>> groupedItems,
  List<bool> expandedStates,
  void Function(int) onToggle,
  PickupInvoiceService pickupInvoiceService,
  List<PickupInvoiceWithItems> allInvoices,
  // Changed the signature to match the new local update method
  void Function(String, int, bool) onItemPickedChanged,
  Set<int> loadingItemIds,
  void Function(int itemId, bool isLoading) onLoadingChange,
) {
  return ListView.builder(
    physics: const AlwaysScrollableScrollPhysics(),
    controller: ScrollController(),
    itemCount: uniqueItemKeys.length,
    itemBuilder: (context, index) {
      final itemKey = uniqueItemKeys[index];
      final itemDetails = itemKey.split('~'); // Use '~' consistently
      final itemName = itemDetails[0];
      final itemSku = itemDetails[1];
      final itemSno = itemDetails[2];
      final invoiceQuantities = groupedItems[itemKey]!;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: const EdgeInsets.all(8.0),
            child: InkWell(
              onTap: () => onToggle(index),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            itemName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: secondaryTeal,
                            ),
                          ),
                        ),
                        Icon(
                          expandedStates[index]
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 16,
                          color: secondaryTeal,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      itemSku,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      itemSno,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expandedStates[index])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorWhite,
                  border: Border.all(color: Colors.grey, width: 1.0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Details:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: invoiceQuantities.length,
                      itemBuilder: (invoiceContext, invoiceIndex) {
                        final invQty = invoiceQuantities[invoiceIndex];

                        final currentInvoice = allInvoices.firstWhereOrNull(
                          (inv) => inv.invoiceNum == invQty.invoiceNum,
                        );
                        //print('invoiceCurrent status ${invQty}');
                        final isDisabled = isInvoiceDisabled(
                          currentInvoice!.invoiceCurrentStatus,
                          currentInvoice.holdStatus,
                          'test',
                        );
                        // Define the card's background color
                        final cardBGColor = getInvoiceCardBGColor(
                          invoiceCurrentStatus:
                              currentInvoice.invoiceCurrentStatus,
                          holdStatus: currentInvoice.holdStatus,
                        );

                        final currentItem = currentInvoice?.items
                            .firstWhereOrNull(
                              (item) =>
                                  item.itemId ==
                                  currentInvoice?.items
                                      .firstWhereOrNull(
                                        (i) =>
                                            '${i.name}~${i.sku}~${i.sno}' ==
                                            itemKey,
                                      )
                                      ?.itemId,
                            );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBGColor, // Apply the color here
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${invQty.invoiceNum}, Qty: ${invQty.qty} ${currentItem?.unit ?? ''}',
                                      ),
                                      const SizedBox(height: 4),
                                      if (currentInvoice?.customerName !=
                                              null &&
                                          currentInvoice!
                                              .customerName!
                                              .isNotEmpty)
                                        Text(invQty.customerName),
                                      if (currentInvoice?.customerEmail !=
                                              null &&
                                          currentInvoice!
                                              .customerEmail!
                                              .isNotEmpty)
                                        Text(
                                          'Email: ${currentInvoice.customerEmail}',
                                        ),
                                      if (currentInvoice?.eComOrderID != null &&
                                          currentInvoice!
                                              .eComOrderID!
                                              .isNotEmpty)
                                        Text(
                                          'Order ID: ${currentInvoice.eComOrderID}',
                                        ),
                                    ],
                                  ),
                                ),
                                // Inside _buildItemWiseView's
                                loadingItemIds.contains(currentItem?.itemId)
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Checkbox(
                                      value: currentItem?.itemPicked == 1,
                                      onChanged:
                                          isDisabled
                                              ? null // 👈 Disable the checkbox here
                                              : (bool? value) {
                                                if (value != null &&
                                                    currentItem != null &&
                                                    currentInvoice != null) {
                                                  onLoadingChange(
                                                    currentItem.itemId,
                                                    true,
                                                  );

                                                  pickupInvoiceService
                                                      .updateItemPickedStatus(
                                                        currentInvoice.id,
                                                        currentItem.itemId,
                                                        value,
                                                        currentInvoice
                                                            .invoiceBranchId,
                                                        currentInvoice
                                                            .invoiceNum,
                                                      )
                                                      .then((
                                                        bool allItemsPicked,
                                                      ) {
                                                        onItemPickedChanged(
                                                          currentInvoice
                                                              .invoiceNum,
                                                          currentItem.itemId,
                                                          value,
                                                        );

                                                        if (allItemsPicked) {
                                                          Navigator.pushReplacement(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder:
                                                                  (_) =>
                                                                      const PickHomeScreen(),
                                                            ),
                                                          );
                                                        }
                                                      })
                                                      .catchError((error) {
                                                        /*print(
                                                          'Failed to update: $error',
                                                        );*/
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Failed to update item',
                                                            ),
                                                          ),
                                                        );
                                                      })
                                                      .whenComplete(() {
                                                        onLoadingChange(
                                                          currentItem.itemId,
                                                          false,
                                                        );
                                                      });
                                                } else {
                                                  /*print(
                                                    'onchange event not worked for view by item',
                                                  );*/
                                                }
                                              },
                                    ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8.0),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class ItemWithInvoice {
  final String invoiceNum;
  final String name;
  final String sku;
  final int qty;
  final String? unit;
  final String sno;

  ItemWithInvoice({
    required this.invoiceNum,
    required this.name,
    required this.sku,
    required this.qty,
    this.unit,
    required this.sno,
  });
}

class PickupInvoiceWithItems {
  final int id;
  final String invoiceNum;
  final String docCreatedAt;
  final DateTime createdAt;
  final String? expectedDeliveryTime;
  final String invoiceStatus; // Keep this as int
  final int invoiceCurrentStatus;
  final String? invoiceLink;
  final String? deliverySalesPerson;
  final String? customerName;
  final String? customerEmail;
  final String? eComOrderID;
  final String? delRemarks;
  final String? expressFlag;
  final int invoiceBranchId;
  final int actionAllowed;
  final int otherBranchDelivery;
  final int hardCopy;
  final int signOnly;
  int holdStatus;
  final String holdAt;
  final String holdReason;
  final String holdReschedule;
  final String codFlag;
  final bool codStatus;
  final List<Item> items;
  final List<PdfDetail> pdfs;
  final int tripID;
  final int tripStatus;
  final String? pmtReceived;
  final String? salesType;
  final String? deliveryType;
  final String? otherBranchName;
  final int soId;
  String? displayCreatedBy;
  String? displaySalesRep;
  String? customerLatitude;
  String? customerLongitude;
  String? customerDistance;
  String? subLocality;
  String? issueDuringDelivery;
  String? deliveryRemarks;

  PickupInvoiceWithItems({
    required this.id,
    required this.invoiceNum,
    required this.docCreatedAt,
    required this.createdAt,
    this.expectedDeliveryTime,
    required this.invoiceStatus,
    required this.invoiceCurrentStatus,
    this.invoiceLink,
    this.customerName,
    this.deliverySalesPerson,
    required this.invoiceBranchId,
    required this.actionAllowed,
    required this.otherBranchDelivery,
    this.otherBranchName,
    this.customerEmail,
    this.eComOrderID,
    this.delRemarks,
    this.expressFlag,
    required this.hardCopy,
    required this.signOnly,
    required this.codFlag,
    required this.codStatus,
    required this.items,
    required this.holdStatus,
    required this.holdAt,
    required this.holdReason,
    required this.holdReschedule,
    required this.pdfs,
    required this.tripID,
    required this.tripStatus,
    this.pmtReceived,
    this.salesType,
    this.deliveryType,
    required this.soId,
    this.displayCreatedBy,
    this.displaySalesRep,
    this.customerLatitude,
    this.customerLongitude,
    this.customerDistance,
    this.subLocality,
    this.issueDuringDelivery,
    this.deliveryRemarks,
  });

  PickupInvoiceWithItems copyWith({
    int? id,
    String? invoiceNum,
    String? docCreatedAt,
    DateTime? createdAt,
    String? expectedDeliveryTime,
    String? invoiceStatus, // Keep this as int in copyWith
    int? invoiceCurrentStatus,
    String? invoiceLink,
    String? customerName,
    String? deliverySalesPerson,
    String? eComOrderID,
    String? delRemarks,
    String? expressFlag,
    String? customerEmail,
    int? invoiceBranchId,
    int? actionAllowed,
    int? otherBranchDelivery,
    String? otherBranchName,
    int? hardCopy,
    int? signOnly,
    int? holdStatus,
    String? holdAt,
    String? holdReason,
    String? holdReschedule,
    String? codFlag,
    bool? codStatus,
    List<Item>? items,
    List<PdfDetail>? pdfs,
    int? tripID,
    int? tripStatus,
    String? pmtReceived,
    String? salesType,
    String? deliveryType,
    int? soId,
    String? displayCreatedBy,
    String? displaySalesRep,
    String? customerLatitude,
    String? customerLongitude,
    String? customerDistance,
    String? subLocality,
    String? issueDuringDelivery,
    String? deliveryRemarks,
  }) {
    return PickupInvoiceWithItems(
      id: id ?? this.id,
      invoiceNum: invoiceNum ?? this.invoiceNum,
      docCreatedAt: docCreatedAt ?? this.docCreatedAt,
      createdAt: createdAt ?? this.createdAt,
      expectedDeliveryTime: expectedDeliveryTime ?? this.expectedDeliveryTime,
      invoiceStatus: invoiceStatus ?? this.invoiceStatus,
      invoiceCurrentStatus: invoiceCurrentStatus ?? this.invoiceCurrentStatus,
      invoiceLink: invoiceLink ?? this.invoiceLink,
      customerName: customerName ?? this.customerName,
      deliverySalesPerson: deliverySalesPerson ?? this.deliverySalesPerson,
      eComOrderID: eComOrderID ?? this.eComOrderID,
      delRemarks: delRemarks ?? this.delRemarks,
      expressFlag: expressFlag ?? this.expressFlag,
      customerEmail: customerEmail ?? this.customerEmail,
      invoiceBranchId: invoiceBranchId ?? this.invoiceBranchId,
      actionAllowed: actionAllowed ?? this.actionAllowed,
      otherBranchDelivery: otherBranchDelivery ?? this.otherBranchDelivery,
      otherBranchName: otherBranchName ?? this.otherBranchName,
      hardCopy: hardCopy ?? this.hardCopy,
      signOnly: signOnly ?? this.signOnly,
      holdStatus: holdStatus ?? this.holdStatus,
      holdAt: holdAt ?? this.holdAt,
      holdReason: holdReason ?? this.holdReason,
      holdReschedule: holdReschedule ?? this.holdReschedule,
      codFlag: codFlag ?? this.codFlag,
      codStatus: codStatus ?? this.codStatus,
      items: items ?? this.items,
      pdfs: pdfs ?? this.pdfs,
      tripID: tripID ?? this.tripID,
      tripStatus: tripStatus ?? this.tripStatus,
      pmtReceived: pmtReceived ?? this.pmtReceived,
      salesType: salesType ?? this.salesType,
      deliveryType: deliveryType ?? this.deliveryType,
      soId: soId ?? this.soId,
      displayCreatedBy: displayCreatedBy ?? this.displayCreatedBy,
      displaySalesRep: displaySalesRep ?? this.displaySalesRep,
      customerLatitude: customerLatitude ?? this.customerLatitude,
      customerLongitude: customerLongitude ?? this.customerLongitude,
      customerDistance: customerDistance ?? this.customerDistance,
      subLocality: subLocality ?? this.subLocality,
      issueDuringDelivery: null,
      deliveryRemarks: null,
    );
  }

  factory PickupInvoiceWithItems.fromJson(Map<String, dynamic> json) {
    // debugPrint('Parsing JSON: $json');
    List<PdfDetail> parsedPdfs = [];
    return PickupInvoiceWithItems(
      id: json['id'] as int,
      invoiceNum: json['doc_num'] as String,
      docCreatedAt: json['doc_created_at'] as String,
      // createdAt: json['created_at'] as DateTime,
      createdAt: DateTime.parse(
        json['created_at'].toString().replaceAll(' ', 'T'),
      ),
      expectedDeliveryTime: json['expectedDeliveryTime'] as String?,
      invoiceLink: null, // Parse as int
      invoiceStatus: _mapStatus(
        json['invoice_status'] is String
            ? int.tryParse(json['invoice_status']) ?? 0
            : json['invoice_status'] ?? 0,
      ),
      invoiceCurrentStatus: json['invoice_status'] as int,
      customerName: json['customer_name'] as String?,
      deliverySalesPerson: null,
      customerEmail: json['customer_email'] as String?,
      invoiceBranchId: json['branch_id'] as int,
      actionAllowed: json['actionAllowed'],
      otherBranchDelivery: 0, //json['other_branch_del'],
      otherBranchName: null,
      eComOrderID: json['order_id'] as String?,
      delRemarks: json['del_remarks'] as String?,
      expressFlag: null,
      tripID: 0,
      tripStatus: 0,
      hardCopy: json['hard_copy'] as int,
      signOnly: json['sign_only'] as int,
      holdStatus: json['holdStatus'],
      holdAt: json['holdAt']?.toString() ?? '',
      holdReason: json['holdReason']?.toString() ?? '',
      holdReschedule: json['holdReschedule']?.toString() ?? '',
      codFlag: json['cod_flag'] as String,
      codStatus: false,
      pmtReceived: json['pmt_received'] as String?,
      salesType: json['sales_type'] as String?,
      deliveryType: json['delivery_type'] as String?,
      soId: json['som_id'] as int,
      displayCreatedBy: null,
      displaySalesRep: null,
      customerLatitude: null,
      customerLongitude: null,
      customerDistance: null,
      subLocality: null,
      items:
          (json['items'] as List<dynamic>)
              .map((itemJson) => Item.fromJson(itemJson))
              .toList(),
      pdfs: parsedPdfs,
    );
  }
  String get paymentStatus {
    switch (pmtReceived?.toLowerCase()) {
      case 'receive payment':
        return 'Paid';
      case 'not paid':
        return 'Not Paid';
      case 'proceed without payment':
        return 'Proceed without payment';
      default:
        return 'Unpaid';
    }
  }

  Color get paymentStatusColor {
    switch (pmtReceived?.toLowerCase()) {
      case 'receive payment':
        return Colors.green;
      case 'not paid':
        return Colors.red;
      case 'proceed without payment':
        return Colors.blue;
      default:
        return Colors.yellow.shade800;
    }
  }

  static String _mapStatus(int status) {
    switch (status) {
      case 1:
        return 'Waiting for Delivery';
      case 2:
        return 'Picking in Progress';
      case 3:
        return 'Picked';
      case 4:
        return 'Ready for Loading';
      case 5:
        return 'Loaded';
      case 6:
        return 'Dispatched';
      case 7:
        return 'Delivery Completed';
      case 11:
        return 'Awaiting Payment';
      default:
        return 'Unknown';
    }
  }

  Color get statusColor {
    switch (invoiceCurrentStatus) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.teal;
      case 4:
        return Colors.orange;
      case 5:
        return Colors.deepOrange;
      case 6:
        return Colors.green;
      case 7:
        return Colors.green.shade900;
      case 11:
        return Colors.deepPurpleAccent.shade100;
      default:
        return Colors.grey;
    }
  }
}

class Item {
  final int itemId;
  final String name;
  final String sku;
  final int qty;
  final String? unit;
  final String sno;
  final int itemPicked;

  Item({
    required this.itemId,
    required this.name,
    required this.sku,
    required this.qty,
    this.unit,
    required this.sno,
    required this.itemPicked,
  });

  Item copyWith({
    int? itemId,
    String? name,
    String? sku,
    int? qty,
    String? unit,
    String? sno,
    int? itemPicked,
  }) {
    return Item(
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      qty: qty ?? this.qty,
      unit: unit ?? this.unit,
      sno: sno ?? this.sno,
      itemPicked: itemPicked ?? this.itemPicked,
    );
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      itemId: json['item_id'] as int,
      name: json['item_name'] as String,
      sku: json['item_sku'] as String,
      qty: json['item_qty'] as int,
      unit: json['item_unit'] as String?,
      sno: json['item_sno'] as String,
      itemPicked: json['item_picked'] as int,
    );
  }
}
