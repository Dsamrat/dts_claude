import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import 'api.dart';

class TripService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();
  Future<List<dynamic>> fetchPickedInvoices(int? branchId, int? tripId) async {
    if (branchId == null) return [];
    tripId ??= 0;
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/branch/$branchId/$tripId/picked_invoices');
    final response = await http
        .get(url, headers: headers)
        .timeout(const Duration(seconds: 120));
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
      final body = jsonDecode(response.body);
      if (body is Map &&
          body['status'] == 'success' &&
          body['invoices'] is List) {
        return body['invoices'];
      } else {
        throw Exception(
          'Failed to load picked invoices: ${body['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception(
        'Failed to load picked invoices: Status code ${response.statusCode}',
      );
    }
  }

  Future<List<dynamic>> fetchTrips(
    int currentUserBranchId,
    int currentUserId,
    String? startDate,
    String? endDate,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trip_lists');
    final body = {
      'currentUserBranchId': currentUserBranchId,
      'currentUserId': currentUserId,
      'start_date': startDate,
      'end_date': endDate,
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('➡️ GET $url');
        print('⬅️ Status Code: ${response.statusCode}');
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
            'Failed to load trips: ${body['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        throw Exception(
          'Failed to load trips: Status code ${response.statusCode}',
        );
      }
    } on TimeoutException catch (_) {
      throw Exception(
        'Request timed out. Please check your internet connection.',
      );
    } catch (e) {
      throw Exception('Error fetching trips: $e');
    }
  }

  Future<bool> createTrip(Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trips');
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
    final json = jsonDecode(response.body);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      return true; // only success
    } else {
      // Throw the actual message from backend
      throw Exception(json['message'] ?? 'Failed to create trip');
    }
  }

  Future<Map<String, dynamic>> updateItemLoaded(
    Map<String, dynamic> dataToSend,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/updateItemLoaded');

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(dataToSend),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: ${jsonEncode(dataToSend)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update item');
    }
  }

  Future<bool> updateTrip(int tripId, Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trips');
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(tripData),
    );
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return response.statusCode == 200;
  }

  Future<bool> deleteTrip(int tripId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trips/$tripId');
    final response = await http.delete(url, headers: headers);
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return response.statusCode == 200;
  }

  Future<List<dynamic>> fetchDrivers(int branchId, int? tripId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trip_drivers/$branchId/$tripId');
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
      return jsonDecode(response.body)
          as List<
            dynamic
          >; // Assuming direct list response as per your Driver API
    } else {
      throw Exception(
        'Failed to load drivers: Status code ${response.statusCode}',
      );
    }
  }

  Future<List<dynamic>> fetchDeliverySupport(int branchId, int? tripId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/trip_delivery_support/$branchId/$tripId');
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
      return jsonDecode(response.body)
          as List<
            dynamic
          >; // Assuming direct list response as per your Driver API
    } else {
      throw Exception(
        'Failed to load drivers: Status code ${response.statusCode}',
      );
    }
  }

  Future<List<dynamic>> fetchAssignedVehicles(
    int? branchId,
    int? tripId,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse(
      '$baseUrl/fetchAssignedVehicleForTrip/$branchId/$tripId',
    );
    final response = await http.get(url, headers: headers);
    _logRequest('GET', url, headers, response);
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is Map && body['status'] == 'success' && body['data'] is List) {
        return body['data'];
      } else {
        throw Exception(
          'Failed to load assigned vehicles: ${body['message'] ?? 'Unknown error'}',
        );
      }
    } else {
      throw Exception(
        'Failed to load assigned vehicles: Status code ${response.statusCode}',
      );
    }
  }

  Future<bool> updateHoldInvoice(Map<String, dynamic> tripData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/updateHoldInvoice');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(tripData),
    );
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Request Body: ${jsonEncode(tripData)}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    return response.statusCode == 200;
  }
  // ==================== HELPER METHODS ====================

  /// Centralized logging for debug mode
  void _logRequest(
    String method,
    Uri url,
    Map<String, String> headers,
    http.Response response, {
    Map<String, dynamic>? body,
  }) {
    if (kDebugMode) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('➡️ $method $url');
      print('📋 Headers: $headers');
      if (body != null) {
        print('📦 Request Body: ${jsonEncode(body)}');
      }
      print('⬅️ Status: ${response.statusCode}');
      print('📄 Response: ${response.body}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    }
  }
}
