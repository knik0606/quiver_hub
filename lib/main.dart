import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'firebase_options.dart';
import 'admin_page.dart';
import 'message_page.dart';

void main() async {
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
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

  // 오디오 초기화 (웹 호환 강화)
  Future<void> _initializeAudio() async {
    try {
      // audioplayers: preload for web
      await _audioPlayer.setVolume(1.0);
    } catch (e) {
      debugPrint('Global audio init error: $e');
    }
  }

  // 앱 전체 새 메시지 감지 (다른 화면 포함 알림)
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
            _hasNewMessageGlobal = true; // 글로벌 배지 업데이트
          });
          await _playGlobalNotificationSound();
        }
      }
      _globalMessageCount = snapshot.docs.length;
    });
  }

  // 글로벌 알림 소리 재생
  Future<void> _playGlobalNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer
          .play(AssetSource('audio/digital-quick.wav')); // 올바른 play 호출 (인수 추가)
    } catch (e) {
      debugPrint('Global sound play error: $e');
    }
  }

  // 읽음 상태 업데이트 (배지 사라짐)
  Future<void> _markAsRead() async {
    try {
      final now = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('user_settings')
          .set({'lastReadMessageTime': now}, SetOptions(merge: true));
      if (mounted) {
        setState(() {
          _hasNewMessageGlobal = false;
        });
      }
    } catch (e) {
      debugPrint('Mark as read error: $e');
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainPage(
        hasNewMessage: _hasNewMessageGlobal, // MainPage에 배지 전달
        onMarkAsRead: _markAsRead, // 읽음 콜백
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

  // 불변 final
  final bool _hasNewNotices = true;
  final bool _hasNewSchedule = false;
  final bool _hasNewAttendanceUpdate = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
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
    // const 제거 (lint)
    const Center(child: Text('Notices Page')),
    const Center(child: Text('Schedule Page')),
    const AthleteListPage(),
    const AdminPage(),
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

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
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
                    // mounted 체크 추가 (lint)
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
        );
      },
    );
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
      ),
      body: _pages.elementAt(displayIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onMarkAsRead(); // await 제거 (void라 불필요, 에러 해결)
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

// AthleteListPage (변경 없음 – 에러 없음)
class AthleteListPage extends StatelessWidget {
  const AthleteListPage({super.key});

  Future<void> _updateAthleteStatus(String docId, String athleteName,
      String newStatus, BuildContext context) async {
    if (!context.mounted) return; // mounted 체크 추가

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Updating status...')));

    final athletesCollection =
        FirebaseFirestore.instance.collection('athletes');
    final mailCollection = FirebaseFirestore.instance.collection('mail');
    final settingsDoc =
        FirebaseFirestore.instance.collection('settings').doc('admin_settings');

    await athletesCollection.doc(docId).update({'status': newStatus});

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$athleteName updated to $newStatus')),
      );
    }

    try {
      final settingSnapshot = await settingsDoc.get();
      final recipientEmail = settingSnapshot.data()?['notificationEmail'];

      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        final now = DateTime.now();
        final timeString = DateFormat('HH:mm').format(now);
        final dateString = DateFormat('yy/MM/dd').format(now);

        final emailSubject =
            '[$newStatus] - $athleteName ($timeString) - $dateString';
        final emailBody = '''
          <p><b>$athleteName</b> - [$newStatus]</p>
          <p><b>Time:</b> $timeString - $dateString</p>
        ''';

        await mailCollection.add({
          'to': recipientEmail,
          'subject': emailSubject,
          'html': emailBody,
        });
      }
    } catch (e) {
      debugPrint('Email send error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('athletes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
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

            final Color outBgColor =
                athleteStatus == 'OUT' ? Colors.grey : Colors.orange;
            final Color inBgColor =
                athleteStatus == 'IN' ? Colors.grey : Colors.green;
            const Color fgColor = Colors.white;

            return Slidable(
              startActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    onPressed: athleteStatus == 'OUT'
                        ? null
                        : (context) {
                            _updateAthleteStatus(
                                athlete.id, athleteName, 'OUT', context);
                          },
                    backgroundColor: outBgColor,
                    foregroundColor: fgColor,
                    icon: Icons.logout,
                    label: 'OUT',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    onPressed: athleteStatus == 'IN'
                        ? null
                        : (context) {
                            _updateAthleteStatus(
                                athlete.id, athleteName, 'IN', context);
                          },
                    backgroundColor: inBgColor,
                    foregroundColor: fgColor,
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
