import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils/sync_helper.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _athleteNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _appTitleController = TextEditingController();
  final _adminBoardNameController = TextEditingController();
  final _adminBoardPasswordController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('admin_settings').get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _appTitleController.text = data['appTitle'] ?? '';
          _emailController.text = data['notificationEmail'] ?? '';
          _passwordController.text = data['adminPassword'] ?? '';
          _adminBoardNameController.text = data['boardName'] ?? '';
          _adminBoardPasswordController.text = data['boardPassword'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _addAthlete() {
    final name = _athleteNameController.text;
    if (name.isNotEmpty) {
      _firestore.collection('athletes').add({
        'name': name,
        'status': 'OUT',
      });
      _athleteNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added successfully.')),
      );
    }
  }

  void _deleteAthlete(String docId) {
    _firestore.collection('athletes').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Athlete deleted.')),
    );
  }

  void _saveSettings() {
    final email = _emailController.text;
    final password = _passwordController.text;
    final appTitle = _appTitleController.text;
    final boardName = _adminBoardNameController.text;
    final boardPassword = _adminBoardPasswordController.text;

    final settingsDoc = _firestore.collection('settings').doc('admin_settings');

    final Map<String, dynamic> settingsToUpdate = {};
    if (appTitle.isNotEmpty) {
      settingsToUpdate['appTitle'] = appTitle;
    }
    if (email.isNotEmpty) {
      settingsToUpdate['notificationEmail'] = email;
    }
    if (password.isNotEmpty) {
      settingsToUpdate['adminPassword'] = password;
    }
    if (boardName.isNotEmpty) {
      settingsToUpdate['boardName'] = boardName;
    }
    if (boardPassword.isNotEmpty) {
      settingsToUpdate['boardPassword'] = boardPassword;
    }

    if (settingsToUpdate.isNotEmpty) {
      settingsDoc.set(settingsToUpdate, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      _appTitleController.clear();
      _emailController.clear();
      _passwordController.clear();
      _adminBoardNameController.clear();
      _adminBoardPasswordController.clear();
      
      // Reload to show saved values (optional, but good for feedback)
      _loadSettings();
    }
  }

  Future<void> _syncData() async {
    await SyncHelper.syncData(
      context, 
      onLoading: (isLoading) {
        if (mounted) {
          setState(() {
            _isLoading = isLoading;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white);
    const inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueAccent),
      ),
      border: OutlineInputBorder(),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Athletes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _athleteNameController,
                        style: textStyle,
                        decoration: inputDecoration.copyWith(labelText: 'Athlete Name'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: _addAthlete,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Current Athletes:', style: textStyle),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('athletes').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var athlete = snapshot.data!.docs[index];
                        return ListTile(
                          title: Text(athlete['name'], style: textStyle),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteAthlete(athlete.id),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 40, color: Colors.white24),
                Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _appTitleController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'App Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Notification Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'New Admin Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const Divider(height: 40, color: Colors.white24),
                Text('Admin Note Page Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminBoardNameController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Admin Board Name (Button Title)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminBoardPasswordController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Admin Board Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        child: const Text('Save Settings'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filled(
                      icon: const Icon(Icons.download),
                      tooltip: 'Load Content from Google Drive',
                      onPressed: _syncData,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Syncing data...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
