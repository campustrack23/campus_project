// lib/core/services/api_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'api_client.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {

  // ---------------------------------------------------------------------------
  // --- NOTICES ---
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getNotices() async {
    final response = await ApiClient.get('/notices');
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load notices: ${response.statusCode}');
  }

  Future<void> createNotice(Map<String, dynamic> data) async {
    final response = await ApiClient.post('/notices', data);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create notice');
    }
  }

  // ---------------------------------------------------------------------------
  // --- ASSIGNMENTS ---
  // ---------------------------------------------------------------------------
  Future<List<dynamic>> getAssignments() async {
    final response = await ApiClient.get('/assignments');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load assignments');
  }

  Future<void> createAssignment(Map<String, dynamic> data) async {
    final response = await ApiClient.post('/assignments', data);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create assignment');
    }
  }

  // STANDARD SUBMISSION (Link/Text)
  Future<void> submitAssignment(String assignmentId, Map<String, dynamic> data) async {
    final response = await ApiClient.post('/assignments/$assignmentId/submit', data);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to submit assignment');
    }
  }

  // TEAMS-STYLE FILE UPLOAD TO FLASK
  Future<void> uploadAssignmentFile(String assignmentId, String filePath) async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken() ?? '';

    var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiClient.baseUrl}/assignments/$assignmentId/upload')
    );

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    var response = await request.send();
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload file to server');
    }
  }

  // ---------------------------------------------------------------------------
  // --- PROFILE ---
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> getProfile(String uid) async {
    final response = await ApiClient.get('/profile/$uid');
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load profile');
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    final response = await ApiClient.put('/profile/$uid', data);
    if (response.statusCode != 200) throw Exception('Failed to update profile');
  }
}