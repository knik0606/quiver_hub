import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'firebase_options.dart';
import 'admin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quiver Hub',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;
  bool _isAdminUnlocked = false;
  Timer? _lockTimer;
  String _appTitle = 'Quiver Hub'; // AppBar 제목을 위한 변수

  final bool _hasNewNotices = true;
  final bool _hasNewSchedule = false;
  final bool _hasNewAttendanceUpdate = false;
  final bool _hasNewMessage = true;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  // Firestore에서 설정을 가져오는 함수
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
    Center(child: Text('Notices Page')),
    Center(child: Text('Schedule Page')),
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
                content: Text('Admin mode has been locked due to inactivity.')),
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

    return showDialog<void>(
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
                  setState(() {
                    _isAdminUnlocked = true;
                    _selectedIndex = 3;
                  });
                  _resetLockTimer();
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
        // ▼▼▼▼▼ 이 부분을 수정했습니다! ▼▼▼▼▼
        title: Text(_appTitle),
      ),
      body: _pages.elementAt(displayIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 메시지 보내기 화면 구현
        },
        tooltip: 'Send a message',
        child: _buildIconWithBadge(Icons.message_outlined, _hasNewMessage),
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

// AthleteListPage 코드는 변경이 필요 없으므로 그대로 둡니다.
class AthleteListPage extends StatelessWidget {
  const AthleteListPage({super.key});

  // Firestore의 선수 상태를 업데이트하고, 이메일 발송을 요청하는 함수
  Future<void> _updateAthleteStatus(
      String docId, String athleteName, String newStatus) async {
    final athletesCollection =
        FirebaseFirestore.instance.collection('athletes');
    final mailCollection = FirebaseFirestore.instance.collection('mail');
    final settingsDoc =
        FirebaseFirestore.instance.collection('settings').doc('admin_settings');

    // 1. 선수의 상태를 먼저 업데이트합니다.
    await athletesCollection.doc(docId).update({'status': newStatus});

    try {
      // 2. Admin 페이지에 저장된 알림 이메일 주소를 가져옵니다.
      final settingSnapshot = await settingsDoc.get();
      final recipientEmail = settingSnapshot.data()?['notificationEmail'];

      // 3. 알림 이메일 주소가 설정되어 있을 때만 메일을 보냅니다.
      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        // 4. 'mail' 컬렉션에 이메일 내용을 담은 문서를 생성합니다.
        await mailCollection.add({
          'to': recipientEmail,
          'subject': 'Attendance Update: $athleteName',
          'html': '''
            <p><b>$athleteName</b> has updated their status to <b>$newStatus</b>.</p>
            <p>Time: ${DateTime.now().toIso8601String()}</p>
          ''',
        });
      }
    } catch (e) {
      print('Failed to send email notification: $e');
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

            return Slidable(
              startActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    onPressed: (context) {
                      _updateAthleteStatus(athlete.id, athleteName, 'OUT');
                    },
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    icon: Icons.logout,
                    label: 'OUT',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    onPressed: (context) {
                      _updateAthleteStatus(athlete.id, athleteName, 'IN');
                    },
                    backgroundColor: Colors.green,
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
