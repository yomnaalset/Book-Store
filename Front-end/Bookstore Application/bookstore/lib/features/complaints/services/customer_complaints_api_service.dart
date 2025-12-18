import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/services/api_client.dart';
import '../models/customer_complaint.dart';

class CustomerComplaintsApiService {
  // Get all complaints for the logged-in customer
  Future<List<CustomerComplaint>> getMyComplaints({String? token}) async {
    try {
      final response = await ApiClient.get(
        '/complaints/',
        queryParams: {'page': '1', 'limit': '100'},
        token: token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> complaintsData = data['data'] ?? [];

        return complaintsData
            .map((json) => CustomerComplaint.fromJson(json))
            .toList();
      } else {
        throw Exception('Failed to load complaints: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CustomerComplaintsApiService: Error getting complaints: $e');
      rethrow;
    }
  }

  // Create a new complaint
  Future<CustomerComplaint> createComplaint({
    required String message,
    required String complaintType,
    String? token,
  }) async {
    try {
      final complaintData = {
        'title': 'Complaint',
        'description': message,
        'complaint_type': complaintType,
      };

      final response = await ApiClient.post(
        '/complaints/',
        body: complaintData,
        token: token,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body);
        // Handle both direct data and nested data structure
        final complaintJson = data['data'] ?? data;
        return CustomerComplaint.fromJson(complaintJson);
      } else {
        final errorBody = response.body;
        debugPrint('CustomerComplaintsApiService: Create failed: $errorBody');
        throw Exception('Failed to create complaint: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CustomerComplaintsApiService: Error creating complaint: $e');
      rethrow;
    }
  }

  // Update a complaint (only if status is pending)
  Future<CustomerComplaint> updateComplaint({
    required int id,
    required String message,
    required String complaintType,
    String? token,
  }) async {
    try {
      final complaintData = {
        'title': 'Complaint',
        'description': message,
        'complaint_type': complaintType,
      };

      final response = await ApiClient.put(
        '/complaints/$id/',
        body: complaintData,
        token: token,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final complaintJson = data['data'] ?? data;
        return CustomerComplaint.fromJson(complaintJson);
      } else {
        final errorBody = response.body;
        debugPrint('CustomerComplaintsApiService: Update failed: $errorBody');
        throw Exception('Failed to update complaint: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('CustomerComplaintsApiService: Error updating complaint: $e');
      rethrow;
    }
  }

  // Get complaint details
  Future<CustomerComplaint> getComplaintDetails({
    required int id,
    String? token,
  }) async {
    try {
      final response = await ApiClient.get('/complaints/$id/', token: token);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          'CustomerComplaintsApiService: Raw API response: ${response.body}',
        );
        debugPrint(
          'CustomerComplaintsApiService: Parsed data keys: ${data.keys.toList()}',
        );

        // Handle different response structures
        Map<String, dynamic> complaintJson;
        if (data.containsKey('data')) {
          complaintJson = data['data'] as Map<String, dynamic>;
        } else if (data.containsKey('complaint')) {
          complaintJson = data['complaint'] as Map<String, dynamic>;
        } else {
          // Assume the data itself is the complaint object
          complaintJson = data as Map<String, dynamic>;
        }

        debugPrint(
          'CustomerComplaintsApiService: Complaint JSON keys: ${complaintJson.keys.toList()}',
        );
        debugPrint(
          'CustomerComplaintsApiService: Description: ${complaintJson['description']}',
        );
        debugPrint(
          'CustomerComplaintsApiService: Responses: ${complaintJson['responses']}',
        );

        return CustomerComplaint.fromJson(complaintJson);
      } else {
        debugPrint(
          'CustomerComplaintsApiService: Failed with status ${response.statusCode}: ${response.body}',
        );
        throw Exception(
          'Failed to load complaint details: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'CustomerComplaintsApiService: Error getting complaint details: $e',
      );
      debugPrint('CustomerComplaintsApiService: Stack trace: $stackTrace');
      rethrow;
    }
  }
}
