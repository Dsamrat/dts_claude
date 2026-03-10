import 'dart:convert';
import 'package:dts/models/delivery_remakrs.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import '../models/issue_remark.dart';
import 'api.dart';

class DriverService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();

  Future<List<dynamic>> fetchDriverTrips(int currentUserId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/branch/$currentUserId/driver_trips');
    final response = await http.get(url, headers: headers);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'success' && body['data'] is List) {
        return body['data'];
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
    // return jsonDecode(response.body);
  }

  Future<List<dynamic>> fetchEmails(int customerId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/fetchEmails/$customerId');
    final response = await http.get(url, headers: headers);

    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'success' && body['data'] is List) {
        return body['data'];
      } else {
        throw Exception(body['message'] ?? 'Unknown error');
      }
    } else {
      // 🔥 New clean version
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Status code ${response.statusCode}');
      }

      final msg =
          (body is Map && body['message'] != null)
              ? body['message']
              : 'Status code ${response.statusCode}';

      throw Exception(msg);
    }
  }

  Future<List<IssueRemark>> fetchIssueRemarks() async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/fetch-issue-remarks');
    final response = await http.get(url, headers: headers);

    final body = jsonDecode(response.body);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return (body['data'] as List).map((e) => IssueRemark.fromJson(e)).toList();
  }

  Future<List<DeliveryRemarks>> fetchDeliveryRemarks() async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/fetch-delivery-complete-remarks');
    final response = await http.get(url, headers: headers);

    final body = jsonDecode(response.body);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return (body['data'] as List)
        .map((e) => DeliveryRemarks.fromJson(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchNames(int customerId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/fetchNames/$customerId');
    final response = await http.get(url, headers: headers);

    if (kDebugMode) {
      print('➡️ GET $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'success' && body['data'] is List) {
        // Ensure each item is Map<String, dynamic>
        return (body['data'] as List).map<Map<String, dynamic>>((e) {
          return Map<String, dynamic>.from(e as Map);
        }).toList();
      } else {
        throw Exception(body['message'] ?? 'Unknown error');
      }
    } else {
      dynamic body;
      try {
        body = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Status code ${response.statusCode}');
      }

      final msg =
          (body is Map && body['message'] != null)
              ? body['message']
              : 'Status code ${response.statusCode}';

      throw Exception(msg);
    }
  }

  Future<String> removeHoldInvoiceNotify(Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/removeHoldInvoiceNotify');
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
      final body = jsonDecode(response.body);
      throw Exception(
        'Failed to load trips: Status code ${response.statusCode}',
      );
    }
  }

  Future<String> submitInvoiceIssue(
    int invoiceId,
    String? remarks,
    int? affectFlag,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update-invoice-issue');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'invoice_id': invoiceId,
        'issue_remark': remarks,
        'affect_flag': affectFlag,
      }),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Request Body: invoice_id: $invoiceId, issue_remark: $remarks');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);

      if (body['status'] == 'success') {
        return body['message']; // <-- return the message correctly
      } else {
        throw Exception(body['message'] ?? 'Unknown error');
      }
    } else {
      throw Exception('Failed: Status code ${response.statusCode}');
    }
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

  Future<String> updateDeliveryCompleted(
    Map<String, dynamic> payloadData,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/update_delivery_completed_driver');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(payloadData),
    );

    if (kDebugMode) {
      debugPrint('➡️ POST $url');
      debugPrint('⬅️ Status Code: ${response.statusCode}');
      debugPrint('⬅️ Request Body: ${jsonEncode(payloadData)}');
      debugPrint('⬅️ Response Body: ${response.body}');
    }

    if (response.statusCode == 401) {
      await handleUnauthenticated();
      throw Exception('Unauthenticated');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update delivery: Status ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded['status'] == 'success') {
      return decoded['message'] ?? 'Trip updated successfully';
    } else {
      throw Exception(decoded['message'] ?? 'Unknown error');
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

  Future<String> uploadTestSignature({
    required Map<String, dynamic> payloadData,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/upload-test-signature');

    final body = jsonEncode(payloadData);

    final response = await http.post(url, headers: headers, body: body);

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: $body');
      print('⬅️ Response Body: ${response.body}');
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

  Future<String> uploadSignatureOperation({
    required Map<String, dynamic> payloadData,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/upload-signature-operation');

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
