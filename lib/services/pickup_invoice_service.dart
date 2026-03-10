import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dts/constants/common.dart';
import '../main.dart';
import '../models/pickup_team_model.dart';
import '../screens/pick_home_screen.dart';
import 'api.dart';

class PickupInvoiceService {
  static const String baseUrl = baseUrlConst;
  final Network _network = Network();

  Future<List<PickupInvoiceWithItems>> getPickupTeamInvoice({
    required int page,
    int? userBranchId,
    int? userId,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/list-pickup-team-invoice');
    final body = {
      'page': page.toString(),
      'userBranchId': userBranchId,
      'userId': userId,
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
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'success') {
        final List<dynamic> invoiceList =
            json['invoices']; // Access the main 'invoices' list
        return invoiceList.map((pickupInvoice) {
          final invoiceHead = pickupInvoice['invoice_head'];
          return PickupInvoiceWithItems.fromJson(
            invoiceHead,
          ); // Create PickupInvoiceWithItems from 'invoice_head'
        }).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load invoices');
      }
    } else {
      throw Exception('Failed to load invoices');
    }
  }

  Future<bool> updateItemPickedStatus(
    int invoiceId,
    int itemId,
    bool isPicked,
    int invoiceBranchId,
    String invoiceNum,
  ) async {
    try {
      final headers = await _network.getAuthHeaders();
      final url = Uri.parse(
        '$baseUrl/update-item-picked',
      ); // Replace with your actual API endpoint
      int? currentUserId;
      int? currentUserBranchId;
      SharedPreferences prefs = await SharedPreferences.getInstance();
      currentUserId = prefs.getInt('userId');
      currentUserBranchId = prefs.getInt('branchId');
      final body = {
        'currentUserId': currentUserId,
        'currentUserBranchId': currentUserBranchId,
        'invoice_id': invoiceId.toString(),
        'item_id': itemId.toString(),
        'item_picked': isPicked ? '1' : '0',
        'branch_id': invoiceBranchId,
        'invoiceNum': invoiceNum,
      };
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (kDebugMode) {
        print('➡️ POST $url');
        print('➡️ Headers: $headers');
        print('➡️ Request Body: ${jsonEncode(body)}');
        print('⬅️ Status Code: ${response.statusCode}');
        print('⬅️ Response Body: ${response.body}');
      }
      if (response.statusCode == 401) {
        await handleUnauthenticated(); // ✅ await here
      }
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return responseData['allItemsPicked'] as bool;
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        String errorMessage =
            errorData['message'] ?? 'Failed to update item status';
        debugPrint(errorMessage);
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('Error updating item status: $e');
      // throw Exception(e.toString()); // Pass the actual error message
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<List<PickupTeamModel>> getPickupTeams(branchId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/pickup-teams-list/$branchId');
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
        final List data = json['persons']; // Extract 'data' array
        if (kDebugMode) print('Fetched teams : $data'); // Add this line
        return data.map((b) => PickupTeamModel.fromJson(b)).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load branches');
      }
    } else {
      throw Exception('Failed to load branches');
    }
  }

  Future<void> assignPickupTeam({
    required int invoiceId,
    required int pkTeamId,
    required List<String> pickupPersons,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assign-pickup-team');
    final body = {
      'invoiceId': invoiceId,
      'pkTeamId': pkTeamId,
      'pickupPersons': pickupPersons,
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
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'success') {
        return;
      } else {
        throw Exception(json['message'] ?? 'Failed to assign pickup team');
      }
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Failed to assign pickup team');
    }
  }
}
