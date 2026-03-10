import 'dart:convert';
// import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/user.dart';
import 'package:dts/constants/common.dart';
import 'api.dart';

class SubuserService {
  static const String baseUrl = baseUrlConst;
  final Network _network = Network();
  Future<List<User>> getSubusers() async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/list-subusers');
    final response = await http.get(url, headers: headers);

    if (kDebugMode) print(response.body);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // Ensure the status is 'success' before proceeding
      if (json['success'] == true) {
        final List data = json['data']; // Extract 'data' array
        if (kDebugMode) print('Fetched subusers: $data'); // Add this line
        return data.map((b) => User.fromJson(b)).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load subusers');
      }
    } else {
      throw Exception('Failed to load subusers');
    }
  }

  Future<void> addSubuser(User user) async {
    final headers = await _network.getAuthHeaders();
    final insResponse = await http.post(
      Uri.parse('$baseUrl/insert-subuser'),
      headers: headers,
      body: jsonEncode(user.toJson()),
    );
    if (insResponse.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (insResponse.statusCode == 200) {
      if (kDebugMode) print('Inserted Successfully');
    } else {
      throw Exception('Not inserted');
    }
  }

  Future<void> updateSubuser(int id, User user) async {
    final headers = await _network.getAuthHeaders();
    await http.put(
      Uri.parse('$baseUrl/update-subuser/$id'),
      headers: headers,
      body: jsonEncode(user.toJson()),
    );
  }

  Future<void> deleteSubuser(int id) async {
    final headers = await _network.getAuthHeaders();
    await http.delete(
      Uri.parse('$baseUrl/delete-subuser/$id'),
      headers: headers,
    );
  }
}
