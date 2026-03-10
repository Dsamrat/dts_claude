import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import 'api.dart';

class CrmService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();

  Future<Map<String, dynamic>> fetchInvoicesForSalesman({
    required int page,
    List<int>? invoiceIds,
    int? userBranchId,
    required String search,
    required String filter,
    String? startDate,
    String? endDate,
  }) async {
    final url = Uri.parse('$baseUrl/crm_invoices');
    final body = {
      'page': page,
      'userBranchId': userBranchId,
      'searchText': search,
      'filter': filter,
      'start_date': startDate,
      'end_date': endDate,
      if (invoiceIds != null) 'invoiceIds': invoiceIds,
    };
    final response = await http.post(
      url,
      headers: await _network.getAuthHeaders(),
      body: jsonEncode(body),
    );
    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Request Body: ${jsonEncode(body)}');
      print('⬅️ Response Body: ${response.body}');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid JSON from server');
    }

    if (response.statusCode == 200) return data;

    throw Exception(data['message'] ?? 'API error');
  }

  Future<Map<String, dynamic>> fetchCrmInvoices({
    List<int>? invoiceIds,
    int? userBranchId,
    required String search,
    required String filter,
    String? startDate, // Add this
    String? endDate, // Add this
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/crm_invoices');
    final body = {
      'userBranchId': userBranchId,
      'searchText': search,
      'filter': filter,
      if (invoiceIds != null) 'invoiceIds': invoiceIds,
      'start_date': startDate,
      'end_date': endDate,
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Request Body: ${jsonEncode(body)}');
      print('⬅️ Response Body: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200 && data['status'] == 'success') {
      return {"status": "success", "data": data['data']};
    }

    // 🟡 Special case: Invoice not found
    if (response.statusCode == 404 && data['status'] == 'error') {
      return {"status": "missing", "missing": List<int>.from(data['missing'])};
    }

    throw Exception(data['message'] ?? "Unexpected Error");
  }

  Future<Map<String, dynamic>> fetchSalesInvoices({int? userId}) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/sales_invoices');
    final body = {'userId': userId};

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Request Body: ${jsonEncode(body)}');
      print('⬅️ Response Body: ${response.body}');
    }

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200 && data['status'] == 'success') {
      return {"status": "success", "data": data['data']};
    }

    // 🟡 Special case: Invoice not found
    if (response.statusCode == 404 && data['status'] == 'error') {
      return {"status": "missing", "missing": List<int>.from(data['missing'])};
    }

    throw Exception(data['message'] ?? "Unexpected Error");
  }

  Future<List<dynamic>> fetchCrmInvoicesOld({
    List<int>? invoiceIds,
    int? userBranchId,
    required String search,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/crm_invoices');
    final body = {
      'userBranchId': userBranchId,
      'searchText': search,

      if (invoiceIds != null) 'invoiceIds': invoiceIds, // ONLY IF PRESENT
    };
    try {
      final response = await http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 120));
      if (kDebugMode) {
        print('➡️ POST $url');
        print('⬅️ Request Body: ${jsonEncode(body)}');
        print('⬅️ Response Body: ${response.body}');
      }
      if (response.statusCode == 401) {
        await handleUnauthenticated(); // ✅ await here
      }
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body is Map &&
            body['status'] == 'success' &&
            body['data'] is List) {
          return body['data'];
        } else {
          throw Exception(
            'Failed to load invoices: ${body['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'Failed to load invoices: Status code ${response.statusCode}',
        );
      }
    } on TimeoutException {
      debugPrint("⏳ Request timed out");
      throw Exception("Request timed out");
    }
  }

  Future<bool> toggleSignOnly(int value, int userId, int invoiceId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/toggle_sign_only');
    final body = {"invoiceId": invoiceId, "userId": userId, "signOnly": value};

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Request Body: ${jsonEncode(body)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      return body['status'] == 'success';
    }

    return false;
  }
}
