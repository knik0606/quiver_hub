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
            // Attendance (Top) - Shows all content
            Column(
              children: [
                _buildHeader('Attendance', Icons.people),
                const AttendanceList(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
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
}
