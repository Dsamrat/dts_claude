import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dts/constants/common.dart';
import 'package:dts/main.dart';

class Network {
  final String _url = baseUrlConst;
  String? token;

  /// --- TOKEN HANDLING ---
  Future<void> _getToken() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    final storedToken = localStorage.getString('token');
    if (storedToken != null) {
      // token = jsonDecode(storedToken)['token'];
      token = storedToken;
    }
  }

  Future<String?> getToken() async {
    if (token == null) {
      await _getToken();
    }
    return token;
  }

  Future<void> logout() async {
    SharedPreferences localStorage = await SharedPreferences.getInstance();
    await localStorage.remove('token');
    token = null;
  }

  Future<Map<String, String>> getAuthHeaders() async {
    await _getToken();
    return {
      'Content-type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// --- 401 HANDLER ---
  void _checkUnauthenticated(http.Response response) {
    if (response.statusCode == 401) {
      handleUnauthenticated();
    }
  }

  Future<http.Response> getData(String apiUrl) async {
    var fullUrl = _url + apiUrl;
    await _getToken();

    final response = await http.get(
      Uri.parse(fullUrl),
      headers: await getAuthHeaders(),
    );

    if (response.statusCode == 401) {
      await handleUnauthenticated(); // ✅ await here
    }

    return response;
  }

  /// --- POST REQUEST ---
  Future<http.Response> authData(
    Map<String, dynamic> data,
    String apiUrl,
  ) async {
    var fullUrl = _url + apiUrl;

    final response = await http.post(
      Uri.parse(fullUrl),
      body: jsonEncode(data),
      headers: await getAuthHeaders(),
    );

    _checkUnauthenticated(response);
    return response;
  }

  /// --- UPDATE TOKEN REQUEST ---
  Future<http.Response> updateToken(
    Map<String, dynamic> data,
    String apiUrl,
  ) async {
    var fullUrl = _url + apiUrl;

    final response = await http.post(
      Uri.parse(fullUrl),
      body: jsonEncode(data),
      headers: await getAuthHeaders(),
    );

    _checkUnauthenticated(response);
    return response;
  }

  /// --- OPTIONAL: GET HEADERS WITHOUT TOKEN ---
  Future<Map<String, String>> getHeaders() async {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization':
          'Bearer 2|Acze12xMn1PuwE2qSUuWk356490nVqP1eXUdITao4206dd80',
    };
  }
}
