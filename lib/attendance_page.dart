import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';



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
    final mailCollection = FirebaseFirestore.instance.collection('mail');

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

    // Trigger email via mail collection
    try {
      await mailCollection.add({
        'name': athleteName,
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('Email request error: $e');
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
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
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
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      child: Card(
        color: const Color(0xFF1E1E1E),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 0), // Margin handled by ListView padding/spacing if needed
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
                color: isIN ? Colors.green.withOpacity(0.2) : Colors.grey[800],
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
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(_startOfDay))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(_endOfDay))
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
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
