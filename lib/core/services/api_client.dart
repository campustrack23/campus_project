// lib/core/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiClient {
  // Hardcoded base URL
  static const String baseUrl = 'https://nonavoidable-reconditely-janell.ngrok-free.dev';

  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    // Fetches the secure Firebase JWT token for the logged-in user
    final token = await user?.getIdToken() ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'ngrok-skip-browser-warning': 'true',  // ← fixes ngrok interstitial
    };
  }

  static Future<http.Response> get(String path, {Map<String, String>? params}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (params != null) uri = uri.replace(queryParameters: params);
    return http.get(uri, headers: await _headers());
  }

  static Future<http.Response> post(String path, Map<String, dynamic> body) async {
    return http.post(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(String path, Map<String, dynamic> body) async {
    return http.put(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> delete(String path) async {
    return http.delete(
      Uri.parse('$baseUrl$path'),
      headers: await _headers(),
    );
  }
}