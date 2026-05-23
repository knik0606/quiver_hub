import 'dart:async';

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
import 'admin_note_page.dart';
import 'utils/sync_helper.dart';
import 'utils/notice_manager.dart';
import 'delete_all_messages_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        );
      } catch (e) {
        if (e.toString().contains("duplicate") ||
            e.toString().contains("already exists")) {
          // Ignore
        } else {
          rethrow;
        }
      }

      // Configure Persistence: OFF for Web (iOS fix), ON for Native
      try {
        FirebaseFirestore.instance.settings =
            const Settings(persistenceEnabled: !kIsWeb);
      } catch (e) {
        // Ignore
      }

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = "Init Error: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text("Initializing App...",
                    style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        ),
      );
    }

    return const MyApp();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _audioPlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot>? _globalMessageSubscription;
  int _globalMessageCount = -1;
  bool _hasNewMessageGlobal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAudio();
    _listenForNewMessagesGlobal();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NoticeManager.checkAndShowNotice();
    });
  }

  Future<void> _initializeAudio() async {
    try {
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint('Global audio init error: $e');
    }
  }

  void _listenForNewMessagesGlobal() {
    _globalMessageSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc('main_thread')
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) async {
      if (_globalMessageCount == -1) {
        _globalMessageCount = snapshot.docs.length;
        return;
      }
      if (snapshot.docChanges.isNotEmpty &&
          snapshot.docs.length > _globalMessageCount) {
        bool hasNewAdminMessage = false;
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data();
            if (data != null && data['senderType'] == 'ADMIN') {
              hasNewAdminMessage = true;
              break;
            }
          }
        }
        if (hasNewAdminMessage && mounted) {
          setState(() {
            _hasNewMessageGlobal = true;
          });
          await _audioPlayer.play(AssetSource('audio/digital-quick.wav'));
        }
      }
      _globalMessageCount = snapshot.docs.length;
    });
  }

  void _markAsRead() {
    if (mounted) {
      setState(() {
        _hasNewMessageGlobal = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _globalMessageSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NoticeManager.checkAndShowNotice();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Quiver Hub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Colors.blueAccent,
          unselectedItemColor: Colors.white54,
        ),
      ),
      initialRoute:
          kIsWeb ? '/' : '/app', // Web starts at Landing, Mobile starts at App
      routes: {
        '/': (context) => kIsWeb
            ? const LandingPage()
            : MainPage(
                hasNewMessage: _hasNewMessageGlobal,
                onMarkAsRead: _markAsRead,
              ),
        '/app': (context) => MainPage(
              hasNewMessage: _hasNewMessageGlobal,
              onMarkAsRead: _markAsRead,
            ),
        '/guest': (context) => MainPage(
              hasNewMessage: _hasNewMessageGlobal,
              onMarkAsRead: _markAsRead,
              viewMode: ViewMode.guest,
            ),
        '/web_admin': (context) => MainPage(
              hasNewMessage: _hasNewMessageGlobal,
              onMarkAsRead: _markAsRead,
              viewMode: ViewMode.admin,
            ),
        '/tv_lobby': (context) => const TvLobbyScreen(),
        '/admin_note': (context) => const AdminNotePage(),
        '/delete_all_messages': (context) => const DeleteAllMessagesScreen(),
      },
    );
  }
}

enum ViewMode { guest, admin, combined }

class MainPage extends StatefulWidget {
  final bool hasNewMessage;
  final VoidCallback onMarkAsRead;
  final ViewMode viewMode;

  const MainPage({
    super.key,
    required this.hasNewMessage,
    required this.onMarkAsRead,
    this.viewMode = ViewMode.combined,
  });

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isAdminUnlocked = false;
  String _appTitle = 'Quiver Hub';

  final bool _hasNewNotices = false;
  final bool _hasNewSchedule = false;
  final bool _hasNewAttendanceUpdate = false;

  Future<void> _syncData() async {
    await SyncHelper.syncData(context);
  }

  @override
  void initState() {
    super.initState();
    _fetchSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NoticeManager.checkAndShowNotice();
    });
  }

  @override
  void dispose() {
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

  List<Widget> get _pages {
    final bool isUserAdmin = widget.viewMode == ViewMode.admin || _isAdminUnlocked;
    switch (widget.viewMode) {
      case ViewMode.guest:
        return [
          const NoticesPage(),
          const SchedulesPage(),
          const AttendancePage(isReadOnly: true),
          MessagePage(isAdmin: isUserAdmin),
        ];
      case ViewMode.admin:
        return [
          const NoticesPage(),
          const SchedulesPage(),
          const AttendancePage(isReadOnly: false),
          MessagePage(isAdmin: isUserAdmin),
          const AdminPage(),
        ];
      case ViewMode.combined:
        return [
          const NoticesPage(),
          const SchedulesPage(),
          const AttendancePage(isReadOnly: false),
          MessagePage(isAdmin: isUserAdmin),
          const AdminPage(),
        ];
    }
  }

  void _onItemTapped(int index) {
    if (widget.viewMode == ViewMode.combined && index == 4 && !_isAdminUnlocked) {
      _showPasswordDialog();
    } else {
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
                          _selectedIndex = 4;
                        });
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

  int get _displayIndex {
    if (widget.viewMode == ViewMode.combined && _selectedIndex == 4 && !_isAdminUnlocked) {
      return 2;
    }
    return _selectedIndex;
  }

  List<BottomNavigationBarItem> get _bottomNavBarItems {
    final baseItems = [
      BottomNavigationBarItem(
        icon: _buildIconWithBadge(Icons.campaign_outlined, _hasNewNotices),
        label: 'Notices',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBadge(Icons.calendar_today_outlined, _hasNewSchedule),
        label: 'Schedule',
      ),
      BottomNavigationBarItem(
        icon: _buildIconWithBadge(Icons.check_circle_outline, _hasNewAttendanceUpdate),
        label: 'Attendance',
      ),
    ];

    if (widget.viewMode == ViewMode.guest) {
      baseItems.add(
        BottomNavigationBarItem(
          icon: _buildIconWithBadge(Icons.message_outlined, widget.hasNewMessage),
          label: 'Message',
        ),
      );
    } else if (widget.viewMode == ViewMode.admin) {
      baseItems.add(
        BottomNavigationBarItem(
          icon: _buildIconWithBadge(Icons.message_outlined, widget.hasNewMessage),
          label: 'Message',
        ),
      );
      baseItems.add(
        BottomNavigationBarItem(
          icon: _buildIconWithBadge(Icons.admin_panel_settings_outlined, false),
          label: 'Admin',
        ),
      );
    } else {
      // combined
      baseItems.add(
        BottomNavigationBarItem(
          icon: _buildIconWithBadge(Icons.message_outlined, widget.hasNewMessage),
          label: 'Message',
        ),
      );
      baseItems.add(
        BottomNavigationBarItem(
          icon: _buildIconWithBadge(Icons.admin_panel_settings_outlined, false),
          label: 'Admin',
        ),
      );
    }
    return baseItems;
  }

  @override
  Widget build(BuildContext context) {
    final int displayIndex = _displayIndex;

    return Title(
      title: _appTitle,
      color: Colors.black,
      child: Scaffold(
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
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: _bottomNavBarItems,
        currentIndex: displayIndex,
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
