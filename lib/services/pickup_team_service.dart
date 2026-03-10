import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import 'api.dart';

class PickupTeamService {
  static const String baseUrl = baseUrlConst;

  final Network _network = Network();
  /*start*/

  Future<List<Map<String, dynamic>>> getPickupTeams(int userBranchId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/list-pickup-teams/$userBranchId');
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
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);

      // Safely access the 'data' list
      final List<dynamic> jsonList = jsonResponse['data'] ?? [];

      return jsonList
          .map<Map<String, dynamic>>((item) => item as Map<String, dynamic>)
          .toList();
    } else {
      throw Exception('Failed to load pickup teams');
    }
  }

  Future<void> deletePickupTeam(int id) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/delete-pickup-team/$id');
    final response = await http.delete(url, headers: headers);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
  }

  Future<List<dynamic>> getPickupPersons({
    int? pickupTeamId,
    required int branchID,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse(
      '$baseUrl/get-pickup-persons/$branchID/$pickupTeamId',
    );
    final response = await http.get(url, headers: headers);
    final json = jsonDecode(response.body);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return json['persons'] ?? [];
  }

  Future<void> addPickupTeam(Map<String, dynamic> pickup) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/insert-pickup-team');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(pickup),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('➡️ Headers: $headers');
      print('⬅️ Request Body: ${jsonEncode(pickup)}');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      if (kDebugMode) print('Inserted Successfully');
    } else {
      throw Exception('Not inserted');
    }
  }

  Future<void> updatePickupTeam(int id, Map<String, dynamic> pickup) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update-pickup-team/$id');

    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(pickup),
    );

    if (kDebugMode) {
      print('➡️ PUT $url');
      print('➡️ Headers: $headers');
      print('⬅️ Request Body: ${jsonEncode(pickup)}');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to update');
    }
  }
}
