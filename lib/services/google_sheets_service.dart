import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoogleSheetsService {
  static const _spreadsheetId = '1C_jy4xH6TqCbYF1BfICAPRnhJQsN_JZ8IkXS77mZfcU';
  static const _scopes = [sheets.SheetsApi.spreadsheetsScope];

  Future<AuthClient> _getAuthClient() async {
    final serviceAccountJson = dotenv.env['GOOGLE_SERVICE_ACCOUNT_KEY'];
    if (serviceAccountJson == null || serviceAccountJson.isEmpty) {
      throw Exception('GOOGLE_SERVICE_ACCOUNT_KEY is not set in .env');
    }

    String cleanJson = serviceAccountJson.trim();
    final int startIndex = cleanJson.indexOf('{');
    final int endIndex = cleanJson.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
      cleanJson = cleanJson.substring(startIndex, endIndex + 1);
    }

    try {
      final credentials =
          ServiceAccountCredentials.fromJson(json.decode(cleanJson));
      return await clientViaServiceAccount(credentials, _scopes);
    } catch (e) {
      throw Exception(
          'Failed to decode GOOGLE_SERVICE_ACCOUNT_KEY JSON. Check .env format. Error: $e');
    }
  }

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
    final client = await _getAuthClient();
    try {
      final sheetsApi = sheets.SheetsApi(client);

      final dateString = '${timestamp.year.toString().substring(2)}.'
          '${timestamp.month.toString().padLeft(2, '0')}.'
          '${timestamp.day.toString().padLeft(2, '0')}';

      final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}:'
          '${timestamp.second.toString().padLeft(2, '0')}';

      final valueRange = sheets.ValueRange(
        values: [
          [dateString, timeString, name, status]
        ],
      );

      await sheetsApi.spreadsheets.values.append(
        valueRange,
        _spreadsheetId,
        'Attendance!A:D',
        valueInputOption: 'USER_ENTERED',
      );
      debugPrint('Successfully logged attendance to sheet');
    } catch (e) {
      debugPrint('Error logging to sheet: $e');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> syncSheetsToFirestore() async {
    final client = await _getAuthClient();
    final db = FirebaseFirestore.instance;

    try {
      final sheetsApi = sheets.SheetsApi(client);

      // 1. Fetch data from Google Sheets
      final noticesResponse = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        'Notices!A2:C',
      );
      final schedulesResponse = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        'Schedules!A2:C',
      );
      final adminNotesResponse = await sheetsApi.spreadsheets.values.get(
        _spreadsheetId,
        'AdminNote!A1:C12',
      );

      final notices = noticesResponse.values ?? [];
      final schedules = schedulesResponse.values ?? [];
      final adminNotesAll = adminNotesResponse.values ?? [];

      // Parse AdminNote
      String boardNameFromSheet = '';
      List<List<Object?>> adminNotesData = [];

      if (adminNotesAll.isNotEmpty) {
        if (adminNotesAll.first.length >= 3) {
          boardNameFromSheet = adminNotesAll.first[2]?.toString() ?? '';
        }
        if (adminNotesAll.length > 2) {
          adminNotesData = adminNotesAll.sublist(2);
        }
      }

      // 2. Clear old Firestore collections
      final noticesBatch = db.batch();
      final noticesSnapshot = await db.collection('notices').get();
      for (var doc in noticesSnapshot.docs) {
        noticesBatch.delete(doc.reference);
      }
      await noticesBatch.commit();

      final schedulesBatch = db.batch();
      final schedulesSnapshot = await db.collection('schedules').get();
      for (var doc in schedulesSnapshot.docs) {
        schedulesBatch.delete(doc.reference);
      }
      await schedulesBatch.commit();

      final adminNotesBatch = db.batch();
      final adminNotesSnapshot = await db.collection('admin_notes').get();
      for (var doc in adminNotesSnapshot.docs) {
        adminNotesBatch.delete(doc.reference);
      }
      await adminNotesBatch.commit();

      // 3. Write new data to Firestore
      final noticesWriteBatch = db.batch();
      for (var i = 0; i < notices.length; i++) {
        final row = notices[i];
        final docRef = db.collection('notices').doc();
        noticesWriteBatch.set(docRef, {
          'pageNumber': row.isNotEmpty ? row[0] : '',
          'content': row.length > 1 ? row[1] : '',
          'imageUrl':
              row.length > 2 ? _convertGoogleDriveUrl(row[2]?.toString()) : '',
          'order': i,
        });
      }
      await noticesWriteBatch.commit();

      final schedulesWriteBatch = db.batch();
      for (var i = 0; i < schedules.length; i++) {
        final row = schedules[i];
        final docRef = db.collection('schedules').doc();
        schedulesWriteBatch.set(docRef, {
          'page': row.length > 1 ? row[1] : '',
          'imageUrl':
              row.length > 2 ? _convertGoogleDriveUrl(row[2]?.toString()) : '',
          'order': i,
        });
      }
      await schedulesWriteBatch.commit();

      final adminNotesWriteBatch = db.batch();
      for (var i = 0; i < adminNotesData.length; i++) {
        final row = adminNotesData[i];
        final content = row.length > 1 ? row[1]?.toString() ?? '' : '';
        final imageUrl = row.length > 2 ? row[2]?.toString() ?? '' : '';

        if (content.isNotEmpty || imageUrl.isNotEmpty) {
          final docRef = db.collection('admin_notes').doc();
          adminNotesWriteBatch.set(docRef, {
            'content': content,
            'imageUrl': _convertGoogleDriveUrl(imageUrl),
            'order': i,
          });
        }
      }
      await adminNotesWriteBatch.commit();

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
        'adminNotesCount': adminNotesData.length,
      };
    } catch (err) {
      debugPrint('FATAL ERROR in syncSheetsToFirestore: $err');
      rethrow;
    } finally {
      client.close();
    }
  }
}
