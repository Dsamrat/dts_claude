import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/dashboard_counts.dart';
import 'package:dts/constants/common.dart';
import 'api.dart';

class DashboardService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();
  Future<DashboardCounts> fetchCounts({
    int? branchId,
    String? startDate,
    String? endDate,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/dashboard/counts');
    final body = {
      if (branchId != null) 'branch_id': branchId.toString(),
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('➡️ Headers: $headers');
      print('➡️ Body: $body');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: ${jsonEncode(body)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }

    if (response.statusCode == 200) {
      final map = json.decode(response.body);
      return DashboardCounts.fromJson(
        map['data'] != null ? {'data': map['data']} : map,
      );
    } else {
      throw Exception(
        'Failed to fetch dashboard counts: ${response.statusCode}',
      );
    }
  }
}
