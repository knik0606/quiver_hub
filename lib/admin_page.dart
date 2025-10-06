import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

    if (settingsToUpdate.isNotEmpty) {
      settingsDoc.set(settingsToUpdate, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      _appTitleController.clear();
      _emailController.clear();
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage Athletes',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _athleteNameController,
                    decoration: const InputDecoration(
                      labelText: 'Athlete Name',
                      border: OutlineInputBorder(),
                    ),
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
            const Text('Current Athletes:'),
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
                      title: Text(athlete['name']),
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
            const Divider(height: 40),
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            TextField(
              controller: _appTitleController,
              decoration: const InputDecoration(
                labelText: 'App Title (e.g., Our School)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Notification Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'New Admin Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Save Settings'),
            ),
          ],
        ),
      ),
    );
  }
}
