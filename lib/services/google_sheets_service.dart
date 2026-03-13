import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSheetsService {
  // Web App URL from Google Apps Script deployment
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbzHGYBKV6T8t-mfO2NCMAngeXsf3AGA0iFfvkhLOcCPGuXK1YL4_5eO1BE3SCObrrzj_A/exec';

  String _convertGoogleDriveUrl(String? url) {
    if (url == null || url.isEmpty || !url.contains('drive.google.com')) {
      return '';
    }
    final regex = RegExp(r'drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final fileId = match.group(1);
      return 'https://drive.google.com/uc?export=view&id=$fileId';
    }
    return '';
  }

  Future<void> logAttendanceToSheet({
    required String name,
    required String status,
    required DateTime timestamp,
  }) async {
    // This is handled by EmailService calling the same GAS URL via POST.
    // Keeping this method for existing call sites, but it's redundant if EmailService is also called.
    debugPrint(
        'logAttendanceToSheet called. Attendance logging is managed via GAS.');
  }

  Future<Map<String, dynamic>> syncSheetsToFirestore() async {
    final db = FirebaseFirestore.instance;

    try {
      // Fetch data from GAS with action=sync
      final response = await http.get(Uri.parse('$_scriptUrl?action=sync'));

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch data from GAS. Status: ${response.statusCode}');
      }

      final Map<String, dynamic> data = jsonDecode(response.body);

      final List<dynamic> notices = data['notices'] ?? [];
      final List<dynamic> schedules = data['schedules'] ?? [];
      final List<dynamic> adminNotesDataRaw = data['adminNotes'] ?? [];
      final String boardNameFromSheet = data['boardName'] ?? '';

      // 1. Clear old Firestore collections using batches for efficiency
      Future<void> _clearCollection(String path) async {
        final snapshot = await db.collection(path).get();
        if (snapshot.docs.isNotEmpty) {
          final batch = db.batch();
          for (var doc in snapshot.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      await _clearCollection('notices');
      await _clearCollection('schedules');
      await _clearCollection('admin_notes');

      // 2. Write new data to Firestore
      final noticesBatch = db.batch();
      for (var i = 0; i < notices.length; i++) {
        final row = List<dynamic>.from(notices[i]);
        final docRef = db.collection('notices').doc();
        noticesBatch.set(docRef, {
          'pageNumber': row.isNotEmpty ? row[0] : '',
          'content': row.length > 1 ? row[1] : '',
          'imageUrl':
              row.length > 2 ? _convertGoogleDriveUrl(row[2]?.toString()) : '',
          'order': i,
        });
      }
      await noticesBatch.commit();

      final schedulesBatch = db.batch();
      for (var i = 0; i < schedules.length; i++) {
        final row = List<dynamic>.from(schedules[i]);
        final docRef = db.collection('schedules').doc();
        schedulesBatch.set(docRef, {
          'page': row.length > 1 ? row[1] : '',
          'imageUrl':
              row.length > 2 ? _convertGoogleDriveUrl(row[2]?.toString()) : '',
          'order': i,
        });
      }
      await schedulesBatch.commit();

      final adminNotesBatch = db.batch();
      for (var i = 0; i < adminNotesDataRaw.length; i++) {
        final row = List<dynamic>.from(adminNotesDataRaw[i]);
        final content = row.length > 1 ? row[1]?.toString() ?? '' : '';
        final imageUrl = row.length > 2 ? row[2]?.toString() ?? '' : '';

        if (content.isNotEmpty || imageUrl.isNotEmpty) {
          final docRef = db.collection('admin_notes').doc();
          adminNotesBatch.set(docRef, {
            'content': content,
            'imageUrl': _convertGoogleDriveUrl(imageUrl),
            'order': i,
          });
        }
      }
      await adminNotesBatch.commit();

      if (boardNameFromSheet.isNotEmpty) {
        await db
            .collection('settings')
            .doc('admin_settings')
            .set({'boardName': boardNameFromSheet}, SetOptions(merge: true));
      }

      return {
        'status': 'success',
        'noticesCount': notices.length,
        'schedulesCount': schedules.length,
        'adminNotesCount': adminNotesDataRaw.length,
      };
    } catch (err) {
      debugPrint('FATAL ERROR in syncSheetsToFirestore: $err');
      rethrow;
    }
  }
}
