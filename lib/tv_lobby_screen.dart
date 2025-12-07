import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'attendance_page.dart';
import 'notices_page.dart';
import 'schedules_page.dart';

class TvLobbyScreen extends StatelessWidget {
  const TvLobbyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Admin Refresh Button
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                onPressed: () => _handleRefresh(context),
                icon: const Icon(Icons.refresh, color: Colors.white54),
                tooltip: 'Force Sync (Admin)',
              ),
            ),
            // Attendance (Top) - Shows all content
            Column(
              children: [
                _buildHeader('Attendance', Icons.people),
                const AttendanceList(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  isReadOnly: true,
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 1),
            // Schedules (Middle) - Fixed height ~600px
            SizedBox(
              height: 600,
              child: Column(
                children: [
                  _buildHeader('Schedules', Icons.calendar_today),
                  const Expanded(child: SchedulesList()),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            // Notices (Bottom) - Fixed height ~600px
            SizedBox(
              height: 600,
              child: Column(
                children: [
                  _buildHeader('Notices', Icons.campaign),
                  const Expanded(child: NoticesList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: const Color(0xFF1E1E1E),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRefresh(BuildContext context) async {
    final passwordController = TextEditingController();
    String? correctPassword = '1234';

    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      correctPassword = settingsDoc.data()?['adminPassword'] ?? '1234';
    } catch (e) {
      debugPrint("Error fetching password: $e");
    }

    if (!context.mounted) return;

    showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Enter Admin Password', style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                 decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    if (passwordController.text == correctPassword) {
                      Navigator.of(context).pop();
                      _syncData(context);
                    } else {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Incorrect password')),
                      );
                    }
                  },
                ),
              ],
            ));
  }

  Future<void> _syncData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Color(0xFF1E1E1E),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Syncing data...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('syncSheetsToFirestore');
      final result = await callable.call();
      debugPrint('Sync result: ${result.data}');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully!')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Sync error: ${e.code} - ${e.message}');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${e.message}')),
        );
      }
    } catch (e) {
       if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }
}
