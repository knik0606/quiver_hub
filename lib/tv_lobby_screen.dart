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
      body: Row(
        children: [
          // Notices Column
          Expanded(
            child: Column(
              children: [
                _buildHeader('Notices', Icons.campaign),
                const Expanded(child: NoticesList()),
              ],
            ),
          ),
          const VerticalDivider(color: Colors.white24, width: 1),
          // Schedules Column
          Expanded(
            child: Column(
              children: [
                _buildHeader('Schedules', Icons.calendar_today),
                const Expanded(child: SchedulesList()),
              ],
            ),
          ),
          const VerticalDivider(color: Colors.white24, width: 1),
          // Attendance Column
          Expanded(
            child: Column(
              children: [
                _buildHeader('Attendance', Icons.people),
                const Expanded(child: AttendanceList()),
              ],
            ),
          ),
        ],
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
