import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DeleteAllMessagesScreen extends StatefulWidget {
  const DeleteAllMessagesScreen({super.key});

  @override
  State<DeleteAllMessagesScreen> createState() => _DeleteAllMessagesScreenState();
}

class _DeleteAllMessagesScreenState extends State<DeleteAllMessagesScreen> {
  final _passwordController = TextEditingController();
  bool _isDeleting = false;

  Future<void> _deleteAllMessages() async {
    final inputPassword = _passwordController.text;
    if (inputPassword.isEmpty) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      
      final correctPassword = settingsDoc.data()?['adminPassword'] ?? '1234';

      if (inputPassword == correctPassword) {
        final messagesRef = FirebaseFirestore.instance
            .collection('chats')
            .doc('main_thread')
            .collection('messages');
            
        final snapshots = await messagesRef.get();
        for (var doc in snapshots.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully deleted all messages.')),
          );
          Navigator.of(context).pushReplacementNamed('/');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect admin password.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete All Messages')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 24),
                const Text(
                  'Are you sure you want to delete all chat messages from the server?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Enter Admin Password',
                    labelStyle: TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isDeleting ? null : _deleteAllMessages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: _isDeleting 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Delete All Messages', style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                  child: const Text('Cancel & Return Home', style: TextStyle(color: Colors.white70)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
