import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/branch.dart';
import '../models/department.dart';
import 'package:dts/constants/common.dart';
import 'api.dart';

class BranchService {
  static const String baseUrl = baseUrlConst;
  final Network _network = Network();

  Future<List<Branch>> getBranches() async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/list-branches');
    final response = await http.get(url, headers: headers);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // Ensure the status is 'success' before proceeding
      if (json['status'] == 'success') {
        final List data = json['data']; // Extract 'data' array
        if (kDebugMode) print('Fetched branches: $data'); // Add this line
        return data.map((b) => Branch.fromJson(b)).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load branches');
      }
    } else {
      throw Exception('Failed to load branches');
    }
  }

  /*DEPARTMENT*/
  Future<List<Department>> getDepartment() async {
    final headers = await _network.getAuthHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/list-department'),
      headers: headers,
    );
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (kDebugMode) print(response.body); // Add this line
      // Ensure the status is 'success' before proceeding
      if (json['status'] == 'success') {
        final List data = json['data']; // Extract 'data' array
        if (kDebugMode) print('Fetched Department: $data'); // Add this line
        return data.map((b) => Department.fromJson(b)).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load branches');
      }
    } else {
      throw Exception('Failed to load branches');
    }
  }

  /*DEPARTMENT*/
}
