import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'admin_page.dart';
import 'message_page.dart';
import 'notices_page.dart';
import 'schedules_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _audioPlayer = AudioPlayer();
  StreamSubscription<QuerySnapshot>? _globalMessageSubscription;
  int _globalMessageCount = -1;
  bool _hasNewMessageGlobal = false;

  @override
  void initState() {
    super.initState();
    _initializeAudio();
    _listenForNewMessagesGlobal();
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
    _globalMessageSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiver Hub',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Colors.blue), // 보라색 -> 파랑색으로 변경
        scaffoldBackgroundColor: Colors.blue[50], // 배경을 아주 연한 파랑색으로 설정
        useMaterial3: true,
      ),
      home: MainPage(
        hasNewMessage: _hasNewMessageGlobal,
        onMarkAsRead: _markAsRead,
      ),
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

  // PageController는 더 이상 사용하지 않으므로 삭제했습니다.

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

  // PageController가 없으므로 dispose에서도 관련 코드를 삭제했습니다.
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

  // _pages 리스트는 다시 간단한 static const 형태로 돌아왔습니다.
  static const List<Widget> _pages = <Widget>[
    NoticesPage(),
    SchedulesPage(),
    AthleteListPage(),
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
        // ▼▼▼ [수정] AppBar의 actions에서 페이지 넘김 버튼들을 삭제하고 새로고침 버튼만 남깁니다. ▼▼▼
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

class AthleteListPage extends StatelessWidget {
  const AthleteListPage({super.key});

  // ▼▼▼ [복구] 이메일 발송 로직 포함된 전체 함수 ▼▼▼
// lib/main.dart 의 AthleteListPage 내부

  Future<void> _updateAthleteStatus(String docId, String athleteName,
      String newStatus, BuildContext context) async {
    if (!context.mounted) return;

    final athletesCollection =
        FirebaseFirestore.instance.collection('athletes');
    final mailCollection = FirebaseFirestore.instance.collection('mail');

    await athletesCollection.doc(docId).update({'status': newStatus});

    final logsCollection =
        FirebaseFirestore.instance.collection('attendance_logs');
    await logsCollection.add({
      'name': athleteName,
      'status': newStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$athleteName updated to $newStatus')),
      );
    }

    // ▼▼▼ 이 부분이 아래와 같이 간결해집니다 ▼▼▼
    try {
      // 이메일 발송에 필요한 최소 정보만 Firestore에 기록합니다.
      // 제목과 내용은 Cloud Function에서 생성하게 됩니다.
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
          return const Center(child: Text('No athletes found.'));
        }

        final athleteDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: athleteDocs.length,
          itemBuilder: (context, index) {
            final athlete = athleteDocs[index];
            final String athleteName = athlete['name'] ?? 'No Name';
            final String athleteStatus = athlete['status'] ?? 'Unknown';

            return Slidable(
              startActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  // lib/main.dart 의 AthleteListPage 내부, build 메서드

// OUT 버튼
                  SlidableAction(
                    onPressed: athleteStatus == 'OUT'
                        ? null
                        : (context) {
                            _updateAthleteStatus(
                                athlete.id, athleteName, 'OUT', context);
                          },
                    // ▼▼▼ 상태에 따라 색상 변경 ▼▼▼
                    backgroundColor:
                        athleteStatus == 'OUT' ? Colors.grey : Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.logout,
                    label: 'OUT',
                  ),

// IN 버튼
                  SlidableAction(
                    onPressed: athleteStatus == 'IN'
                        ? null
                        : (context) {
                            _updateAthleteStatus(
                                athlete.id, athleteName, 'IN', context);
                          },
                    // ▼▼▼ 상태에 따라 색상 변경 ▼▼▼
                    backgroundColor:
                        athleteStatus == 'IN' ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.login,
                    label: 'IN',
                  ),
                ],
              ),
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title:
                      Text(athleteName, style: const TextStyle(fontSize: 18)),
                  trailing: Text(
                    athleteStatus,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color:
                          athleteStatus == 'IN' ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
