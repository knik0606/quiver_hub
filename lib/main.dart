import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'firebase_options.dart';

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

// BottomNavigationBar 상태를 관리하는 메인 페이지
class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0; // 현재 선택된 탭의 인덱스

  // 각 탭에 보여줄 페이지 위젯 목록
  static const List<Widget> _pages = <Widget>[
    Center(child: Text('Notices Page')), // 0: 공지사항
    Center(child: Text('Schedule Page')), // 1: 일정
    AthleteListPage(), // 2: 출석부
    Center(child: Text('Admin Page')), // 3: 관리자 모드
  ];

  // 탭이 선택되었을 때 호출될 함수
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiver Hub'),
      ),
      body: _pages.elementAt(_selectedIndex), // 선택된 탭에 맞는 페이지를 보여줌
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 탭이 4개일 때 고정
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: 'Notices',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.check_circle_outline),
            activeIcon: Icon(Icons.check_circle),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

// 선수 목록을 보여주는 출석부 페이지 위젯
class AthleteListPage extends StatelessWidget {
  const AthleteListPage({super.key});

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
                      // TODO: Implement 'OUT' action
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
                      // TODO: Implement 'IN' action
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
