import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dts/services/api.dart';
import '../constants/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final userNameController = TextEditingController();
  final passwordController = TextEditingController();
  @override
  void dispose() {
    userNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void updateFcmToken(String userId) async {
    debugPrint(userId);
    String? fcmToken = await FirebaseMessaging.instance.getToken();

    if (fcmToken != null) {
      // Send token to your Laravel API
      final network = Network();
      final data = {'user_id': userId, 'fcm_token': fcmToken};
      debugPrint("Sending data to API: ${jsonEncode(data)}");
      try {
        final response = await network.updateToken(data, "/updateFcmToken");

        if (response.statusCode == 200) {
          debugPrint("FCM Token updated");
        } else {
          final error = jsonDecode(response.body);
          _showErrorDialog(error['message'] ?? 'FCM Token update failed');
        }
      } catch (e) {
        if (kDebugMode) print("FCM Token error: $e");
        _showErrorDialog('An error occurred. Please try again.');
      }
    }
  }

  void onLogin() async {
    final userName = userNameController.text.trim();
    final password = passwordController.text;
    final data = {'userName': userName, 'password': password};
    final network = Network();

    try {
      final response = await network.authData(data, "/login");
      if (kDebugMode) {
        print('➡️ POST Login');
        print('⬅️ Request Body: ${jsonEncode(data)}');
        print('⬅️ Response Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'token',
          responseData['data']['token'].toString(),
        );
        await prefs.setInt(
          'reportAccess',
          responseData['data']['reportAccess'],
        );
        await prefs.setInt('viewOnly', responseData['data']['viewOnly']);
        await prefs.setString(
          'userName',
          responseData['data']['name'].toString(),
        );
        await prefs.setString(
          'branchName',
          responseData['data']['branchName'].toString(),
        );
        await prefs.setString(
          'deptName',
          responseData['data']['deptName'].toString(),
        );

        await prefs.setInt(
          'isPickupTeam',
          responseData['data']['isPickupTeam'],
        );
        await prefs.setInt('multiBranch', responseData['data']['multiBranch']);
        await prefs.setInt(
          'branchId',
          responseData['data']['branchId'],
        ); //branch ID
        await prefs.setInt(
          'departmentId',
          responseData['data']['departmentId'],
        );
        await prefs.setInt('userId', responseData['data']['id']);
        await prefs.setString('appVersion', responseData['data']['appVersion']);
        debugPrint('before call update FCM Token');
        updateFcmToken((responseData['data']['id']).toString());
        if (!mounted) return; // ✅ Safe usage of context
        Navigator.pushReplacementNamed(context, '/dashboard_screen');
      } else {
        final error = jsonDecode(response.body);
        _showErrorDialog(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      if (kDebugMode) print("Login error: $e");
      _showErrorDialog('An error occurred. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void onSignUpRedirect() {
    Navigator.pushNamed(context, '/signup'); // Update to your sign up route
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background image
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryTeal, lightTeal2],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // 🔹 Login Form content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/img/argon-logo.webp', // Your logo asset here
                    height: 60, // Increased size
                    width: 264,
                  ),

                  const SizedBox(height: 32),

                  // Email TextField
                  TextField(
                    controller: userNameController,
                    decoration: const InputDecoration(
                      hintText: "User Name",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password TextField
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: "Password",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Login Button
                  ElevatedButton(
                    onPressed: onLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: secondaryTeal,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white, // Change text color to white
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
