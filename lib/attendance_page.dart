import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import 'services/email_service.dart';
import 'services/google_sheets_service.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212), // Dark background
      body: AttendanceList(),
    );
  }
}

class AttendanceList extends StatefulWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final bool isReadOnly;

  const AttendanceList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
    this.isReadOnly = false,
  });

  @override
  State<AttendanceList> createState() => _AttendanceListState();
}

class _AttendanceListState extends State<AttendanceList> {
  @override
  void initState() {
    super.initState();
    _deleteOldLogs();
  }

  Future<void> _deleteOldLogs() async {
    try {
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final logsCollection =
          FirebaseFirestore.instance.collection('attendance_logs');
      final oldLogsSnapshot = await logsCollection
          .where('timestamp', isLessThan: Timestamp.fromDate(twoDaysAgo))
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in oldLogsSnapshot.docs) {
        batch.delete(doc.reference);
      }
      if (oldLogsSnapshot.docs.isNotEmpty) {
        await batch.commit();
        debugPrint(
            'Deleted ${oldLogsSnapshot.docs.length} old attendance logs.');
      }
    } catch (e) {
      debugPrint('Error deleting old logs: $e');
    }
  }

  // Helper to get today's start and end timestamps
  DateTime get _startOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _endOfDay {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59);
  }

  Future<void> _updateAthleteStatus(String docId, String athleteName,
      String newStatus, BuildContext context) async {
    final athletesCollection =
        FirebaseFirestore.instance.collection('athletes');

    // Update status in athletes collection
    await athletesCollection.doc(docId).update({'status': newStatus});

    // Add log to attendance_logs
    final logsCollection =
        FirebaseFirestore.instance.collection('attendance_logs');
    await logsCollection.add({
      'name': athleteName,
      'status': newStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$athleteName updated to $newStatus'),
          backgroundColor: newStatus == 'IN' ? Colors.green : Colors.grey,
        ),
      );
    }

    // Asynchronously handle email and sheet logging using Dart services
    _handleBackgroundServices(athleteName, newStatus);
  }

  Future<void> _handleBackgroundServices(
      String athleteName, String newStatus) async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      final recipientEmail =
          settingsDoc.data()?['notificationEmail'] as String?;

      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        debugPrint('>>> 알림 수신 이메일: $recipientEmail');
        final emailService = EmailService();
        await emailService.sendAttendanceEmail(
          recipientEmail: recipientEmail,
          name: athleteName,
          status: newStatus,
        );
      } else {
        debugPrint('>>> 알림 수신 이메일이 설정되지 않았습니다.');
      }

      final sheetsService = GoogleSheetsService();
      await sheetsService.logAttendanceToSheet(
        name: athleteName,
        status: newStatus,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('>>> Error in background services: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('athletes')
          .orderBy('name')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'No athletes found.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        final athleteDocs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          itemCount: athleteDocs.length,
          itemBuilder: (context, index) {
            final athlete = athleteDocs[index];
            final String athleteName = athlete['name'] ?? 'No Name';
            final String athleteStatus = athlete['status'] ?? 'Unknown';
            final String docId = athlete.id;

            return _buildAthleteCard(
                context, docId, athleteName, athleteStatus);
          },
        );
      },
    );
  }

  Widget _buildAthleteCard(BuildContext context, String docId,
      String athleteName, String athleteStatus) {
    final bool isIN = athleteStatus == 'IN';

    return Slidable(
      key: Key(docId),
      enabled: !widget.isReadOnly,
      // Swipe Right reveals startActionPane
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: isIN
                ? null
                : (context) =>
                    _updateAthleteStatus(docId, athleteName, 'IN', context),
            backgroundColor: isIN ? Colors.grey[800]! : Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.login,
            label: 'IN',
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
          SlidableAction(
            onPressed: !isIN
                ? null
                : (context) =>
                    _updateAthleteStatus(docId, athleteName, 'OUT', context),
            backgroundColor: !isIN ? Colors.grey[800]! : Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.logout,
            label: 'OUT',
            borderRadius:
                const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(
            bottom: 0), // Margin handled by ListView padding/spacing if needed
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            title: Text(
              athleteName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isIN
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isIN ? Colors.green : Colors.grey,
                  width: 1,
                ),
              ),
              child: Text(
                athleteStatus,
                style: TextStyle(
                  color: isIN ? Colors.greenAccent : Colors.grey[400],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 10),
                    const Text(
                      "Today's Activity",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildDailyLogs(athleteName),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDailyLogs(String athleteName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_logs')
          .where('name', isEqualTo: athleteName)
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay))
          .where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint("Firestore Error: ${snapshot.error}");
          return SelectableText(
            'Error: ${snapshot.error}',
            style: const TextStyle(color: Colors.red),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text(
            'No records for today.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          );
        }

        final logs = snapshot.data!.docs;

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final data = logs[index].data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            final timestamp = data['timestamp'] as Timestamp?;
            final timeStr = timestamp != null
                ? DateFormat('HH:mm').format(timestamp.toDate())
                : '--:--';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    status == 'IN' ? Icons.circle : Icons.circle_outlined,
                    size: 12,
                    color: status == 'IN' ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      color: status == 'IN' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeStr,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
