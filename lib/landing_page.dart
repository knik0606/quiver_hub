// import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    _checkStandalone();
  }

  void _checkStandalone() {
    // Check if running as PWA/Standalone
    /*
    if (kIsWeb) {
      final isStandalone =
          html.window.matchMedia('(display-mode: standalone)').matches;
      if (isStandalone) {
        // Schedule navigation after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
           Navigator.of(context).pushReplacementNamed('/app');
        });
      }
    }
    */
  }

  Future<void> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    String? correctPassword = '1234'; // Fallback
    
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      correctPassword = settingsDoc.data()?['adminPassword'] ?? '1234';
    } catch (e) {
      debugPrint("Error fetching password: $e");
    }

    if (!mounted) return;
    
    showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Enter Access Password', style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: passwordController,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
                ),
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
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/app');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sports_score,
                  size: 80,
                  color: Colors.white,
                ),
                const SizedBox(height: 20),
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('settings')
                      .doc('admin_settings')
                      .snapshots(),
                  builder: (context, snapshot) {
                    String title = 'Quiver Hub';
                    if (snapshot.hasData && snapshot.data != null) {
                      final data = snapshot.data!.data() as Map<String, dynamic>?;
                      if (data != null && data.containsKey('appTitle')) {
                        title = data['appTitle'] ?? 'Quiver Hub';
                      }
                    }
                    return Title(
                      title: title,
                      color: Colors.black,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                _buildButton(
                  context,
                  label: '▶ Enter',
                  icon: Icons.tv,
                  onPressed: () {
                    Navigator.of(context).pushNamed('/tv_lobby');
                  },
                  isPrimary: true,
                ),
                // "Open Attendance App" button removed as requested
              ],
            ),
          ),
          // Hidden button at bottom left
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _showPasswordDialog,
              child: Container(
                width: 40,
                height: 40,
                color: Colors.transparent, // Invisible but clickable
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
  }) {
    return SizedBox(
      width: 280,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? Colors.blueAccent : const Color(0xFF2C2C2C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isPrimary ? 4 : 0,
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
