import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/common.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ArgonDrawer extends StatefulWidget {
  final String? currentPage;
  const ArgonDrawer({Key? key, this.currentPage}) : super(key: key);

  @override
  _ArgonDrawerState createState() => _ArgonDrawerState();
}

class _ArgonDrawerState extends State<ArgonDrawer> {
  String? _userName = "";
  String? branchName = ""; // Added user email
  String? deptName = ""; // Added user email
  bool _isLoading = true;
  int? _userDeptId = 0;
  int? reportAccess = 0;
  int? viewOnly = 0;
  String? _currentVersion;
  String? _latestVersion;
  // bool _forceUpdateRequired = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('userName') ?? "User";
      branchName =
          prefs.getString('branchName') ??
          "No Branch Assigned"; // Load email, default value provided
      deptName = prefs.getString('deptName') ?? "No Department Assigned";
      _isLoading =
          false; // Set loading to false after data is loaded (or failed to load)
      _userDeptId = prefs.getInt('departmentId') ?? 0;
      reportAccess = prefs.getInt('reportAccess') ?? 0;
      viewOnly = prefs.getInt('viewOnly') ?? 0;
      _latestVersion = prefs.getString('appVersion') ?? "1.0.0";
    });
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = packageInfo.version;
      // if (_currentVersion != _latestVersion) {
      //   _forceUpdateRequired = true;
      // }
    });
  }

  Future<void> _logout() async {
    if (kDebugMode) print('[ArgonDrawer] Attempting logout...');
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // This is the crucial line
    if (kDebugMode) print('[ArgonDrawer] SharedPreferences cleared.');

    if (navigatorKey.currentContext != null) {
      // Using navigatorKey for consistency
      if (kDebugMode)
        print('[ArgonDrawer] Navigating to /login via pushAndRemoveUntil.');
      Navigator.pushAndRemoveUntil(
        navigatorKey.currentContext!,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    } else {
      if (kDebugMode)
        print(
          '[ArgonDrawer] navigatorKey.currentContext is null, cannot navigate.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        /*color: const Color(
          0xFF11181C,
        ),*/
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [secondaryTeal, lightTeal1],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        // Darker background for the entire drawer
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  _buildDrawerHeader(),
                  _buildDrawerMenuTiles(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    bool isOutdated = _currentVersion != _latestVersion;
    return Container(
      height:
          (isOutdated) ? 250.0 : 200.0, // Increased height for better spacing
      padding: const EdgeInsets.only(top: 24.0, left: 16.0, bottom: 16),
      decoration: const BoxDecoration(
        // No background color here, let the Drawer's color handle it
        border: Border(
          bottom: BorderSide(
            color:
                Colors
                    .white10, // Subtle border instead of shadow for separation
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Logo (replace with your actual logo widget)
          Image.asset(
            'assets/img/argon-logo.webp', // Your logo asset here
            fit: BoxFit.contain,
            height: 60, // Increased size
            width: 264,
          ),

          const SizedBox(height: 12), // Increased spacing
          _isLoading
              ? const CircularProgressIndicator(
                color: Colors.white,
              ) // Show loading indicator
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName ?? "User",
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 18.0,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),

                  Text(
                    deptName ?? "No Department Assigned",
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                  Text(
                    branchName ?? "No Branch Assigned",
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                  Text(
                    "Version: v$_currentVersion",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (isOutdated) ...[
                    const SizedBox(height: 2),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        /*launchUrl(
                          Uri.parse(
                            "https://drive.google.com/file/d/1-9M6hH-BEGwX2Xen2IU_Ni53NSYwTXqb/view?usp=drive_link",
                          ),
                          mode: LaunchMode.externalApplication,
                        );*/
                      },
                      child: Text("Update to v$_latestVersion"),
                    ),
                  ],
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuTiles() {
    return Column(
      children: [
        _buildDrawerTile(
          icon: Icons.home,
          title: "Dashboard",
          routeName: "/dashboard_screen",
          isSelected: widget.currentPage == "Dashboard",
        ),
        _buildDrawerTile(
          icon: Icons.local_shipping,
          title: "Deliveries",
          // routeName: "/home",
          routeName:
              _userDeptId == 2
                  ? '/pick_home_screen'
                  : _userDeptId == 4
                  ? '/crm_home_screen'
                  : _userDeptId == 10
                  ? '/sales_home_screen'
                  : _userDeptId == 7
                  ? '/driver_home_screen'
                  : _userDeptId == 5
                  ? '/accounts_home_screen'
                  : '/home',

          isSelected: widget.currentPage == "Deliveries",
        ),

        if (_userDeptId == 1 || viewOnly == 1) ...[
          _buildDrawerTile(
            icon: Icons.directions_car,
            title: "Vehicles",
            routeName: "/vehicle_list",
            isSelected: widget.currentPage == "Vehicles",
          ),
          _buildDrawerTile(
            icon: Icons.person,
            title: "Pickup",
            routeName: "/pickup_team",
            isSelected: widget.currentPage == "Pickup",
          ),
          /*_buildDrawerTile(
            icon: Icons.assignment,
            title: "Expedition",
            routeName: "/trip_list_screen",
            isSelected: widget.currentPage == "Expedition",
          ),*/
          _buildDrawerTile(
            icon: Icons.assignment,
            title: "Trips",
            routeName: "/expedition_screen",
            isSelected: widget.currentPage == "Trips",
          ),
          const Divider(
            color: Colors.white10, // Divider color
          ),
        ],

        if (reportAccess == 1)
          // 👇 New Reports menu
          _buildDrawerTile(
            icon: Icons.assessment,
            title: "Tracker",
            onTap: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              final token = prefs.getString('token');
              if (token != null) {
                // final url = "https://yourdomain.com/auto-login/$token";
                final url = "$reportUrlConst/auto-login/$token";
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
          ),
        _buildDrawerTile(
          icon: Icons.logout,
          title: "Logout",
          routeName: "/logout", // You can use a custom route for logout
          onTap: _logout, // Use the _logout method
          isLogout: false, //custom parameter to change the text color.
        ),
      ],
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    String? routeName,
    bool isSelected = false,
    VoidCallback? onTap, // Make onTap optional
    bool isLogout = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color:
            isSelected
                ? Colors.white10
                : Colors
                    .transparent, // Background color for selected tile, more subtle
        borderRadius: BorderRadius.circular(
          8,
        ), // Rounded corners for the selected tile
      ),
      margin: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 8,
      ), // Add some margin around the tile, reduced horizontal margin.
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white, // Icon color is always white
        ),
        title: Text(
          title,
          style: TextStyle(
            color:
                isLogout
                    ? Colors.red
                    : Colors
                        .white, // Text color based on isLogout, default to white
            fontWeight:
                isSelected
                    ? FontWeight.w600
                    : FontWeight.normal, // Bold if selected
          ),
        ),
        onTap:
            onTap ??
            () {
              // Only navigate if onTap is not provided
              if (routeName != null && mounted) {
                Navigator.of(
                  context,
                ).pushReplacementNamed(routeName); //pushReplacementNamed
              }
            },
        selected:
            isSelected, //redundant because i already set the color in the container.
        selectedTileColor: Colors.transparent, //remove selectedTileColor.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            8,
          ), //same border radius as the container
        ),
      ),
    );
  }
}
