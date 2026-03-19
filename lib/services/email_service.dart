import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class EmailService {
  // Web App URL from Google Apps Script deployment
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbzHGYBKV6T8t-mfO2NCMAngeXsf3AGA0iFfvkhLOcCPGuXK1YL4_5eO1BE3SCObrrzj_A/exec';

  Future<void> sendAttendanceEmail({
    required String recipientEmail,
    required String name,
    required String status,
  }) async {
    // We don't need to send the email directly here anymore.
    // The Apps Script handles both logging to Sheets and sending the email.
    // This function can be kept for API compatibility but now delegates to the HTTP POST.
    try {
      final now = DateTime.now();

      final Map<String, dynamic> data = {
        'name': name,
        'status': status,
        'recipientEmail': recipientEmail,
        'timestamp': now.toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(_scriptUrl),
        // Use text/plain to avoid CORS preflight (OPTIONS request) on Flutter Web.
        // Google Apps Script does not support OPTIONS requests.
        headers: {'Content-Type': 'text/plain'},
        body: jsonEncode(data),
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        // Apps script redirects (302) on success sometimes, which http package follows on mobile/desktop.
        // On Web, it might return 200 if handled by the browser fetch API.
        debugPrint('Attendance data sent to GAS successfully. Status: ${response.statusCode}');
      } else {
        debugPrint(
            'Failed to send data to GAS. Status code: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending data to GAS: $e');
    }
  }

  Future<void> sendNewMessageEmail({
    required String recipientEmail,
    required String senderType,
    required String messageText,
    required String messageId,
  }) async {
    // For future if we want chatting emails via GAS, we need another endpoint or
    // check the action type in the payload.
    // Currently, just printing to console as a placeholder.
    debugPrint('Chat notification email via GAS not yet implemented.');
  }
}
