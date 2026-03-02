import 'dart:async';
import 'package:flutter/material.dart';
import '../services/google_sheets_service.dart';

class SyncHelper {
  static Future<void> syncData(BuildContext context,
      {ValueChanged<bool>? onLoading}) async {
    final bool useDialog = onLoading == null;
    bool isDialogShowing = false;

    if (useDialog) {
      isDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (BuildContext dialogContext) {
          return Dialog(
            backgroundColor: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 20),
                      Text("Syncing data...",
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext, rootNavigator: true)
                          .pop('dialog');
                      isDialogShowing = false;
                    },
                    child: const Text("Cancel",
                        style: TextStyle(color: Colors.redAccent)),
                  )
                ],
              ),
            ),
          );
        },
      ).then((_) => isDialogShowing = false);
    } else {
      onLoading(true);
    }

    try {
      final sheetsService = GoogleSheetsService();

      // Using the local dart service instead of Firebase Functions
      final data = await sheetsService.syncSheetsToFirestore().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('The sync operation timed out.');
        },
      );

      debugPrint('Sync result: $data');

      final notices = data['noticesCount'] ?? 0;
      final schedules = data['schedulesCount'] ?? 0;
      final adminNotes = data['adminNotesCount'] ?? 0;

      if (context.mounted) {
        // Show detailed success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Success! Synced: $notices Notices, $schedules Schedules, $adminNotes Admin Notes.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on TimeoutException catch (_) {
      debugPrint('Sync error: Timeout');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync timed out. Network might be slow.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (useDialog) {
        // Guaranteed to pop the dialog if still showing
        if (isDialogShowing && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop('dialog');
        }
      } else {
        onLoading(false);
      }
    }
  }
}
