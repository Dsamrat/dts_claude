import 'package:dts/screens/dashboard_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/login_screen.dart';
import '../screens/splash_screen.dart';

class RedirectHandler extends StatefulWidget {
  const RedirectHandler({super.key});

  @override
  State<RedirectHandler> createState() => _RedirectHandlerState();
}

class _RedirectHandlerState extends State<RedirectHandler> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndRedirect();
  }

  Future<void> _checkAuthAndRedirect() async {
    await Future.delayed(const Duration(seconds: 2)); // Splash delay

    if (!mounted) {
      if (kDebugMode)
        print('[RedirectHandler] Widget not mounted, aborting redirect.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    // Get as String
    final _userDeptId = prefs.getInt('departmentId') ?? 0;
    if (kDebugMode) {
      print(
        '[RedirectHandler] Token found: ${token != null && token.isNotEmpty}',
      );
      print('[RedirectHandler] _userDeptId: $_userDeptId');
    }

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      // User is not logged in or token is invalid
      if (kDebugMode) print('[RedirectHandler] Navigating to LoginScreen.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SplashScreen(); // Replace with your splash screen widget
  }
}
