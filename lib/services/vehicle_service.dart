import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dts/constants/common.dart';
import '../main.dart';
import 'api.dart';

class VehicleService {
  static const String baseUrl = baseUrlConst; // Change this
  final Network _network = Network();

  Future<List<dynamic>> fetchDrivers(int branchId, int? asDriverId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/drivers/$branchId/$asDriverId');
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

  Future<List<dynamic>> fetchDeliverySupports(int branchId, int? asId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/deliverySupports/$branchId/$asId');
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

  Future<List<dynamic>> fetchVehicles(
    int currentUserBranchId,
    int? asVehicleId,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse(
      '$baseUrl/getvehicles/$currentUserBranchId/$asVehicleId',
    );
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
      final List<dynamic> jsonBody = jsonDecode(response.body);
      return jsonBody; // ✅ Return directly
    } else {
      throw Exception('Failed to load vehicles (${response.statusCode})');
    }
  }

  Future<List<dynamic>> fetchAssignedVehicles(int? branchId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/branch/$branchId/assignvehicle');
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

  Future<bool> createVehicle(Map<String, dynamic> VehicleData) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assignvehicle');
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(VehicleData),
    );
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: $VehicleData');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to create vehicle: ${response.body}');
    }
  }

  Future<bool> updateVehicle(
    int tripId,
    Map<String, dynamic> VehicleData,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assignvehicle/$tripId');
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode(VehicleData),
    );
    if (kDebugMode) {
      print('➡️ GET $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Request Body: $VehicleData');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    //return response.statusCode == 200;
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to update vehicle: ${response.body}');
    }
  }

  Future<bool> deleteVehicle(int tripId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assignvehicle/$tripId');
    final response = await http.delete(url, headers: headers);
    if (kDebugMode) {
      print('➡️ delete $url');
      print('⬅️ tripId: $tripId');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    //return response.statusCode == 200;
    if (response.statusCode == 200) {
      return true;
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['message'] ?? 'Failed to delete vehicle');
    }
  }
}
