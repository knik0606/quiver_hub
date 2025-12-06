import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'firebase_options.dart';
import 'admin_page.dart';
import 'message_page.dart';
import 'notices_page.dart';
import 'schedules_page.dart';
import 'attendance_page.dart';
import 'tv_lobby_screen.dart';
import 'landing_page.dart';

void main() {
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeFlutterFire();
  }

  Future<void> _initializeFlutterFire() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
            ),
        '/tv_lobby': (context) => const TvLobbyScreen(),
      },
    );
  }
}

class MainPage extends StatefulWidget {
  final bool hasNewMessage;
  final VoidCallback onMarkAsRead;

  const MainPage({
    super.key,
    required this.hasNewMessage,
    required this.onMarkAsRead,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isAdminUnlocked = false;
  Timer? _lockTimer;
  String _appTitle = 'Quiver Hub';

  final bool _hasNewNotices = false;
  final bool _hasNewSchedule = false;
  final bool _hasNewAttendanceUpdate = false;

  Future<void> _syncData() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Syncing data..."),
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
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully!')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Sync error: ${e.code} - ${e.message}');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${e.message}')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  void _fetchSettings() {
    FirebaseFirestore.instance
        .collection('settings')
        .doc('admin_settings')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        setState(() {
          _appTitle = snapshot.data()?['appTitle'] ?? 'Quiver Hub';
        });
      }
    });
  }

  static const List<Widget> _pages = <Widget>[
    NoticesPage(),
    SchedulesPage(),
    AttendancePage(),
    AdminPage(),
  ];

  void _resetLockTimer() {
    _lockTimer?.cancel();
    _lockTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        setState(() {
          _isAdminUnlocked = false;
        });
        if (ScaffoldMessenger.of(context).mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin mode has been locked due to inactivity.'),
            ),
          );
        }
      }
    });
  }

  void _onItemTapped(int index) {
    if (index == 3 && !_isAdminUnlocked) {
      _showPasswordDialog();
    } else {
      if (_isAdminUnlocked) _resetLockTimer();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    final settingsDoc = await FirebaseFirestore.instance
        .collection('settings')
        .doc('admin_settings')
        .get();
    final correctPassword = settingsDoc.data()?['adminPassword'] ?? '1234';

    if (!mounted) return;
    showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              title: const Text('Enter Admin Password'),
              content: TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
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
                      if (mounted) {
                        setState(() {
                          _isAdminUnlocked = true;
                          _selectedIndex = 3;
                        });
                        _resetLockTimer();
                      }
                      Navigator.of(context).pop();
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

  Widget _buildIconWithBadge(IconData iconData, bool hasBadge) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData),
        if (hasBadge)
          Positioned(
            top: -2,
            right: -4,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final int displayIndex =
        (_selectedIndex == 3 && !_isAdminUnlocked) ? 2 : _selectedIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(_appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync data from Sheet',
            onPressed: _syncData,
          ),
        ],
      ),
      body: _pages.elementAt(displayIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onMarkAsRead();
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MessagePage()),
            );
          }
        },
        tooltip: 'Send a message',
        child:
            _buildIconWithBadge(Icons.message_outlined, widget.hasNewMessage),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(Icons.campaign_outlined, _hasNewNotices),
            label: 'Notices',
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
                Icons.calendar_today_outlined, _hasNewSchedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: _buildIconWithBadge(
                Icons.check_circle_outline, _hasNewAttendanceUpdate),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon:
                _buildIconWithBadge(Icons.admin_panel_settings_outlined, false),
            label: 'Admin',
          ),
        ],
        currentIndex: displayIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
