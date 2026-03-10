import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import 'api.dart';

class AccountsService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();

  Future<Map<String, dynamic>> fetchAccountsInvoices({
    required int page,
    List<int>? invoiceIds,
    required String filter,
    int? userBranchId,
    required String search,
    String? startDate,
    String? endDate,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/accounts_invoices');

    final body = {
      'page': page,
      'filter': filter,
      'userBranchId': userBranchId,
      'searchText': search,
      'start_date': startDate,
      'end_date': endDate,
      if (invoiceIds != null) 'invoiceIds': invoiceIds,
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

    if (response.statusCode == 401) {
      await handleUnauthenticated();
      throw Exception('Unauthenticated');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid JSON from server');
    }

    if (response.statusCode == 200) {
      return data;
    }

    // ✅ IMPORTANT: handle all other cases
    throw Exception(
      'Failed to fetch invoices (status: ${response.statusCode})',
    );
  }

  Future<String> updateDispatchedStatus(Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update_dispatched_status');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(tripData),
    );
    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: ${jsonEncode(tripData)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        return body['message'];
      } else {
        throw Exception(
          'Failed to load trips: ${body['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception(
        'Failed to load trips: Status code ${response.statusCode}',
      );
    }
  }

  Future<String> updateTripCompleted(Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update_trip_completed');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(tripData),
    );
    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: ${jsonEncode(tripData)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body['status'] == 'success') {
        return body['message'];
      } else {
        throw Exception(
          'Failed to load trips: ${body['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception(
        'Failed to load trips: Status code ${response.statusCode}',
      );
    }
  }

  Future<String> uploadSignature({
    required Map<String, dynamic> payloadData,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/upload-signature');

    final body = jsonEncode(payloadData);

    final response = await http.post(url, headers: headers, body: body);

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: $body');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded['status'] == 'success') {
        return decoded['message'] ?? 'Signature uploaded successfully.';
      } else {
        throw Exception(decoded['message'] ?? 'Upload failed');
      }
    } else {
      throw Exception('Upload failed with status code ${response.statusCode}');
    }
  }

  Future<String> markPaymentReceived({
    required Map<String, dynamic> payloadData,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update-payment-received');

    final body = jsonEncode(payloadData);

    final response = await http.post(url, headers: headers, body: body);

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: $body');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (response.statusCode == 200 && decoded['status'] == 'success') {
        return decoded['message'] ?? 'Updated successfully.';
      } else {
        throw Exception(decoded['message'] ?? 'Upload failed');
      }
    } else {
      throw Exception('Upload failed with status code ${response.statusCode}');
    }
  }
}
