import 'package:dts/screens/crm_home_screen.dart';
import 'package:dts/screens/home_screen.dart';
import 'package:dts/screens/sales_home_screen.dart';
import 'package:dts/screens/trip_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/branch_service.dart';
import '../services/dashboard_service.dart';
import '../models/branch.dart';
import '../models/dashboard_counts.dart';
import '../widgets/drawer.dart';
import '../screens/accounts_home_screen.dart';
import '../widgets/home_widgets/FilterSection.dart';
import '../widgets/navbar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BranchService _branchService = BranchService();
  final DashboardService _dashboardService = DashboardService();

  List<Branch> branchesDrop = [];
  DashboardCounts? counts;

  bool loading = false;
  bool uiDisabled = false;

  int? selectedBranchId;
  int? userDepartmentId;
  int? isMultiBranch;
  DateTimeRange? dateRange;
  bool showFilters = false;

  bool get isTodayRange {
    if (dateRange == null) return true; // ✅ no filter = today

    final now = DateTime.now();

    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    return isSameDay(dateRange!.start, now) && isSameDay(dateRange!.end, now);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await loadUserDetails();
    await loadInitialData();
  }

  Future<void> loadUserDetails() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isMultiBranch = prefs.getInt('multiBranch');
      selectedBranchId = prefs.getInt('branchId');
      userDepartmentId = prefs.getInt('departmentId');
    });
  }

  Future<void> loadInitialData() async {
    setState(() => loading = true);
    if (isMultiBranch == 1) {
      branchesDrop = await _branchService.getBranches();
    }

    if (selectedBranchId == null && branchesDrop.isNotEmpty) {
      selectedBranchId = branchesDrop.first.id;
    }

    await _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() {
      loading = true;
      uiDisabled = true;
    });

    try {
      String? start, end;

      if (dateRange != null) {
        start = DateFormat('yyyy-MM-dd').format(dateRange!.start);
        end = DateFormat('yyyy-MM-dd').format(dateRange!.end);
      } else {
        start = null;
        end = null;
      }

      counts = await _dashboardService.fetchCounts(
        branchId: selectedBranchId,
        startDate: start,
        endDate: end,
      );
    } catch (e) {
      // print("❌ Dashboard API failed: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to load dashboard data")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
          uiDisabled = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFE0F2F1),
          appBar: Navbar(
            title: "Dashboard",
            rightOptions: true,
            showFilter: true,
            filterEnabled: showFilters,
            onFilterPressed: () {
              setState(() => showFilters = !showFilters);
            },
          ),
          drawer: ArgonDrawer(currentPage: "Dashboard"),
          body: Column(
            children: [
              FilterSection(
                showFilters: showFilters,
                showBranch: true,
                showDate: true,
                isMultiBranch: isMultiBranch,
                branchesDrop: branchesDrop,
                selectedBranchId: selectedBranchId,
                onBranchChanged: (branch) async {
                  selectedBranchId = branch?.id;
                  await _loadCounts();
                },
                startDate: dateRange?.start,
                endDate: dateRange?.end,
                onDateRangeChanged: (range) async {
                  dateRange = range;
                  await _loadCounts();
                },
              ),
              Expanded(child: _mainContent(context)),
            ],
          ),
        ),
        if (uiDisabled)
          IgnorePointer(
            ignoring: false,
            child: Container(color: Colors.black.withOpacity(0.1)),
          ),
      ],
    );
  }

  Widget _mainContent(BuildContext context) {
    // Determine header text based on date filter
    String group2Header =
        dateRange != null
            ? "📅 ${DateFormat('MMM dd').format(dateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange!.end)}"
            : "📊 Today's Activity";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ========== GROUP 1: In-Progress Orders (NO DATE FILTER) ==========
          _buildSectionHeader('📊 In-Progress Count (As of Date)'),
          const SizedBox(height: 12),
          _dashboardGrid(isGroup1: true),

          const SizedBox(height: 30),

          // ========== GROUP 2: Completed Orders (WITH DATE FILTER) ==========
          _buildSectionHeader(group2Header),
          const SizedBox(height: 12),
          _dashboardGrid(isGroup1: false),

          const SizedBox(height: 30),

          // ========== GROUP 3: Summary (WITH DATE FILTER) ==========
          _summaryRow(),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.shade200, width: 1),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade900,
        ),
      ),
    );
  }

  Widget _dashboardGrid({required bool isGroup1}) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    double childAspectRatio;

    if (screenWidth >= 1200) {
      crossAxisCount = 4;
      childAspectRatio = 1.3;
    } else if (screenWidth >= 900) {
      crossAxisCount = 3;
      childAspectRatio = 1.3;
    } else if (screenWidth >= 600) {
      crossAxisCount = 3;
      childAspectRatio = 1.3;
    } else {
      crossAxisCount = 3;
      childAspectRatio = 1.0;
    }

    // ========== GROUP 1: In-Progress Orders ==========
    final group1Cards = [
      {
        "title": "WAITING FOR DELIVERY",
        "value": counts?.waitingForDelivery,
        "color": Colors.grey,
        "filterId": 1,
      },
      {
        "title": "PICKING IN PROGRESS",
        "value": counts?.pickingInProgress,
        "color": Colors.blue,
        "filterId": 2,
      },
      {
        "title": "PICKED",
        "value": counts?.picked,
        "color": Colors.teal,
        "filterId": 3,
      },
      {
        "title": "READY FOR LOADING",
        "value": counts?.readyForLoading,
        "color": Colors.orange,
        "filterId": 4,
      },
      {
        "title": "LOADED",
        "value": counts?.loaded,
        "color": Colors.deepOrange,
        "filterId": 5,
      },
      {
        "title": "DISPATCHED",
        "value": counts?.dispatched,
        "color": Colors.green,
        "filterId": 6,
      },
      {
        "title": "AWAITING PAYMENT",
        "value": counts?.awaitingPayment,
        "color": Colors.deepPurpleAccent.shade100,
        "filterId": 11,
      },
      {
        "title": "HOLD",
        "value": counts?.hold,
        "color": Colors.blue.shade300,
        "filterId": 9,
      },
      {
        "title": "RESCHEDULE",
        "value": counts?.reschedule,
        "color": Colors.orange.shade300,
        "filterId": 10,
      },
      {
        "title": "SIGN-ONLY",
        "value": counts?.signOnly,
        "color": Colors.red.shade300,
        "filterId": 999,
      },
    ];

    // ========== GROUP 2: Completed Orders ==========
    final group2Cards = [
      {
        "title": "DELIVERY COMPLETED",
        "value": counts?.deliveryCompleted,
        "color": Colors.green.shade900,
        "filterId": 7,
      },
      {
        "title": "CANCELLED",
        "value": counts?.cancelled,
        "color": Colors.red,
        "filterId": 8,
      },
      {
        "title": "BR DELIVERED",
        "value": counts?.brDelivered, // 🔄 Replace with actual API field
        "color": Colors.indigo.shade600,
        "filterId": 12, // Update with actual filter ID
      },
      {
        "title": "CUSTOMER COLLECTION",
        "value": counts?.customerCollection, // 🔄 Replace with actual API field
        "color": Colors.purple.shade500,
        "filterId": 13, // Update with actual filter ID
      },
      {
        "title": "COURIER",
        "value": counts?.courier, // 🔄 Replace with actual API field
        "color": Colors.cyan.shade700,
        "filterId": 14, // Update with actual filter ID
      },
      {
        "title": "SIGN ONLY COMPLETED",
        "value": counts?.signOnlyCompleted, // 🔄 Replace with actual API field
        "color": Colors.amber.shade800,
        "filterId": 15, // Update with actual filter ID
      },
    ];

    final cardData = isGroup1 ? group1Cards : group2Cards;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cardData.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final data = cardData[index];

        final isMobile = screenWidth < 600;
        final cardHeight = isMobile ? 120.0 : 160.0;
        final titleFontSize = isMobile ? 12.0 : 14.0;
        final valueFontSize = isMobile ? 22.0 : 28.0;
        final padding = isMobile ? 8.0 : 10.0;

        return _card(
          title: data["title"] as String,
          value: data["value"] as int?,
          color: data["color"] as Color,
          filterId: data["filterId"] as int,
          cardHeight: cardHeight,
          titleFontSize: titleFontSize,
          valueFontSize: valueFontSize,
          padding: padding,
        );
      },
    );
  }

  Widget _card({
    required String title,
    required int? value,
    required int filterId,
    required Color color,
    required double cardHeight,
    required double titleFontSize,
    required double valueFontSize,
    required double padding,
  }) {
    bool _isHovered = false;

    return StatefulBuilder(
      builder:
          (context, setState) => MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTap: () {
                const disabledFilterIds = {12, 13, 14, 15};

                if (disabledFilterIds.contains(filterId)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'This card is for information only and cannot be opened.',
                      ),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                String? start;
                String? end;
                if (dateRange != null) {
                  start = DateFormat('yyyy-MM-dd').format(dateRange!.start);
                  end = DateFormat('yyyy-MM-dd').format(dateRange!.end);
                } else {
                  start = null;
                  end = null;
                }
                const asOfDateFilterIds = {1, 2, 3, 4, 5, 6, 9, 10, 11, 999};
                if (asOfDateFilterIds.contains(filterId)) {
                  start = null;
                  end = null;
                }

                if (userDepartmentId == 5) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => AccountsHomeScreen(
                            initialFilterOption: filterId,
                            initialBranchId: selectedBranchId,
                            initialStart: start,
                            initialEnd: end,
                            initialPage: 'Home',
                          ),
                    ),
                  );
                } else if (userDepartmentId == 4) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CrmHomeScreen(
                            initialFilterOption: filterId,
                            initialBranchId: selectedBranchId,
                            initialStart: start,
                            initialEnd: end,
                            initialPage: 'Home',
                          ),
                    ),
                  );
                } else if (userDepartmentId == 10) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => SalesHomeScreen(
                            initialFilterOption: filterId,
                            initialBranchId: selectedBranchId,
                            initialStart: start,
                            initialEnd: end,
                            initialPage: 'Home',
                          ),
                    ),
                  );
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => HomeScreen(
                            initialFilterOption: filterId,
                            initialBranchId: selectedBranchId,
                            initialStart: start,
                            initialEnd: end,
                            initialPage: 'Home',
                          ),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: cardHeight,
                transform:
                    _isHovered
                        ? Matrix4.translationValues(0, -3, 0)
                        : Matrix4.identity(),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(_isHovered ? 0.1 : 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(padding),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: titleFontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          "${value ?? 0}",
                          style: TextStyle(
                            fontSize: valueFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _summaryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _summary(
          Icons.local_shipping,
          "RUNNING VEHICLES",
          counts?.runningVehicles,
          subValue: counts?.totalVehicles,
          forceDash: !isTodayRange,
        ),
        _summary(Icons.route, "TRIPS TODAY", counts?.totalTripsToday),
        _summary(
          Icons.receipt_long,
          "INVOICES IN TRIPS",
          counts?.invoicesInTrips,
        ),
      ],
    );
  }

  Widget _summary(
    IconData icon,
    String label,
    int? value, {
    int? subValue,
    bool forceDash = false,
  }) {
    String displayValue;

    if (forceDash) {
      displayValue = "- / -";
    } else if (subValue != null) {
      displayValue = "${value ?? 0} / ${subValue ?? 0}";
    } else {
      displayValue = "${value ?? 0}";
    }

    return GestureDetector(
      onTap: () {
        if (userDepartmentId == 1) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TripListScreen()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      },
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.teal),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
