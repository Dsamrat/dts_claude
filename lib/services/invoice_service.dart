import 'dart:convert';
import 'package:dts/models/sales_person.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../models/invoice.dart';
import 'package:dts/constants/common.dart';
import '../models/pickup_team_model.dart';
import 'api.dart';

class InvoiceService {
  static const String baseUrl = baseUrlConst;
  final Network _network = Network();

  // Future<List<Invoice>> getInvoices({
  Future<Map<String, dynamic>> getInvoices({
    required int page,
    required String filter,
    // required bool isPickup,
    int? isMultiBranch,
    int? userBranchId,
    int? userActualBranchId,
    int? currentUserId,
    required String search,
    required String groupBy,
    String? startDate,
    String? endDate,
    List<int>? invoiceIds,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/list-invoices');
    final body = {
      'page': page.toString(),
      'filter': filter,
      'invoiceIds': invoiceIds,
      'isMultiBranch': isMultiBranch,
      'userBranchId': userBranchId,
      'userActualBranchId': userActualBranchId,
      'currentUserId': currentUserId,
      'searchText': search,
      'groupBy': groupBy,
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
      final json = jsonDecode(response.body);

      if (json['status'] == 'success') {
        final invoicesJson = json['invoices'];

        List data = [];
        int total = 0;

        if (invoicesJson is Map && invoicesJson.containsKey('data')) {
          data = invoicesJson['data'] ?? [];
          total = invoicesJson['total'] ?? data.length;
        } else if (invoicesJson is List) {
          data = invoicesJson;
          total = data.length;
        } else {
          throw Exception('Unexpected invoices format: $invoicesJson');
        }

        return {
          'invoices': data.map((b) => Invoice.fromJson(b)).toList(),
          'total': total,
        };
      } else {
        throw Exception(json['message'] ?? 'Failed to load invoices');
      }
    } else {
      throw Exception('Failed to load invoices');
    }
  }

  Future<Map<String, dynamic>> checkAndGetNewInvoice({
    required List<int> invoiceIds,
    required String filter,
    int? userBranchId,
    int? userActualBranchId,
    int? currentUserId,
    required String search,
    String? startDate,
    String? endDate,
  }) async {
    final headers = await _network.getAuthHeaders();
    // Use a specific endpoint for the event check
    final url = Uri.parse('$baseUrl/get-invoice');
    final body = {
      // 🎯 Change: Pass the array of IDs with a new key name
      'invoiceIds': invoiceIds,
      'filter': filter,
      'userBranchId': userBranchId,
      'userActualBranchId': userActualBranchId,
      'currentUserId': currentUserId,
      'searchText': search,
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
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // 🎯 Change: Expect a list of invoices under the key 'invoices' (plural)
      if (json['invoices'] != null && json['invoices'] is List) {
        final List<Invoice> matchedInvoices = (json['invoices'] as List)
            .map((item) => Invoice.fromJson(item as Map<String, dynamic>))
            .toList();
        // Return the list of matched Invoices
        return {'invoices': matchedInvoices};
      } else {
        // Return an empty list if no matches found
        return {'invoices': <Invoice>[]};
      }
    }
    // Handle API errors as needed
    throw Exception('Failed to check new invoice status.');
  }

  Future<bool> toggleInvoiceStatus(
    String? action,
    String? reason,
    String? dateTime,
    int confirmed,
    int currentUserId,
    int userBranchId,
    int invoiceId,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/toggle-invoice-status');
    // final parsedDateTime = dateTime != null ? DateTime.tryParse(dateTime) : null;
    final body = {
      'action': action,
      'reason': reason,
      'confirmed': confirmed,
      'dateTime': dateTime,
      'currentUserId': currentUserId,
      'userBranchId': userBranchId,
      'invoiceId': invoiceId,
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
      final Map<String, dynamic> resData = jsonDecode(response.body);
      final status = (resData['status'] ?? '').toString().toLowerCase();
      return status == 'success';
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }

  Future<List<SalesPerson>> getSalesPersons(int branchId) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/sales-person-list/$branchId');
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
        return data.map((b) => SalesPerson.fromJson(b)).toList();
      } else {
        throw Exception(json['message'] ?? 'Failed to load branches');
      }
    } else {
      throw Exception('Failed to load branches');
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
    required int currentUserId,
    required int pkTeamId,
    required List<String> pickupPersons,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assign-pickup-team');
    final body = {
      'invoiceId': invoiceId,
      'currentUserId': currentUserId,
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

  Future<void> assignToReadyForLoading({
    required int invoiceId,
    required int currentUserId,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/assign-readyForLoading');
    final body = {'invoiceId': invoiceId, 'currentUserId': currentUserId};
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
        throw Exception(json['message'] ?? 'Failed to update status');
      }
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Failed to update status');
    }
  }

  Future<void> completeInvoiceAPI({
    required int invoiceId,
    required int currentUserId,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/complete-invoice');
    final body = {'invoiceId': invoiceId, 'currentUserId': currentUserId};
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
        throw Exception(json['message'] ?? 'Failed to update status');
      }
    } else {
      final json = jsonDecode(response.body);
      throw Exception(json['message'] ?? 'Failed to update status');
    }
  }

  Future<bool> updateCourierInfo({
    required int invoiceId,
    required String awbNumber,
    required double cost,
    String? remarks,
    required int currentUserId,
  }) async {
    try {
      final headers = await _network.getAuthHeaders();

      // Ensure JSON content-type
      headers['Content-Type'] = 'application/json';

      final url = Uri.parse('$baseUrl/update-courier-info');

      final body = {
        'invoice_id': invoiceId,
        'awbNumber': awbNumber,
        'cost': cost.toString(), // convert to string for Laravel DECIMAL
        'remarks': remarks ?? '',
        'currentUserId': currentUserId, // REQUIRED
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (kDebugMode) {
        print('➡️ POST $url');
        print('➡️ Headers: $headers');
        print('➡️ Body: ${jsonEncode(body)}');
        print('⬅️ Response: ${response.body}');
      }

      if (response.statusCode == 401) {
        await handleUnauthenticated();
      }

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> getInvoiceDetails({
    required int invoiceId,
  }) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse(
      '$baseUrl/show-invoice-details/$invoiceId',
    ); // invoice number in URL
    final response = await http.get(url, headers: headers);
    if (kDebugMode) {
      print('➡️ POST $url');
      print('➡️ Headers: $headers');
      print('⬅️ Status Code: ${response.statusCode}');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['status'] == 'success') {
        return json['invoices']; // This is a Map, not a List
      } else {
        throw Exception(json['message'] ?? 'Failed to load invoice');
      }
    } else {
      throw Exception('Failed to load invoice');
    }
  }

  Future<List<dynamic>> getInvoiceStatus({required int invoiceId}) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/show-invoice-status/$invoiceId');
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
      if (json['status'] == 'success') {
        return json['invoices'] as List<dynamic>; // FIXED: cast to list
      } else {
        throw Exception(json['message'] ?? 'Failed to load invoice status');
      }
    } else {
      throw Exception('Failed to load invoice status');
    }
  }

  Future<bool> updateDeliveryType({
    required int invoiceId,
    required String deliveryType,
  }) async {
    try {
      final headers = await _network.getAuthHeaders();
      final url = Uri.parse('$baseUrl/update-delivery-type');
      final body = {
        'invoice_id': invoiceId.toString(),
        'delivery_type': deliveryType,
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
        return true;
      } else {
        debugPrint("Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("Error: $e");
      return false;
    }
  }

  /* Future<bool> toggleDeliveryType(
      String deliveryType,
      int userId,
      int invoiceId, {
        int? salesPersonId,
        bool confirmTripReassign = false,
      }) async {

  }*/
  Future<bool> toggleDeliveryType(
    String? deliveryType,
    int currentUserId,
    int invoiceId, {
    int? salesPersonId,
    bool confirmTripReassign = false,
  }) async {
    if (deliveryType == null || deliveryType.isEmpty) {
      throw Exception('Delivery type cannot be null or empty');
    }

    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/toggle-delivery-type');

    final body = {
      "deliveryType": deliveryType,
      "currentUserId": currentUserId,
      "invoiceId": invoiceId,
      "confirm_trip_reassign": confirmTripReassign,
    };

    if (salesPersonId != null) {
      body["salesperson_id"] = salesPersonId;
    }

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );

    if (kDebugMode) {
      print('➡️ POST $url');
      print('➡️ Headers: $headers');
      print('➡️ Body: $body');
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> toggleBranch(
    int selectedBranchId,
    int currentUserId,
    int invoiceId,
  ) async {
    final headers = await _network.getAuthHeaders();
    final url = Uri.parse('$baseUrl/toggle-branch');
    final body = {
      'selectedBranchId': selectedBranchId,
      'currentUserId': currentUserId,
      'invoiceId': invoiceId,
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
      print('⬅️ Response Body: ${response.body}');
    }
    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }
    if (response.statusCode == 200) {
      // Decode JSON response into Map
      final decoded = jsonDecode(response.body);

      // Optional: Validate that it has the expected structure
      if (decoded is Map<String, dynamic>) {
        return decoded;
      } else {
        throw Exception('Unexpected response format');
      }
    } else {
      throw Exception('Failed to update status: ${response.statusCode}');
    }
  }
}
