import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  late AnimationController _rainbowController;

  @override
  void initState() {
    super.initState();
    _checkStandalone();
    _rainbowController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rainbowController.dispose();
    super.dispose();
  }

  void _checkStandalone() {
    // Check if running as PWA/Standalone
  }

  Future<void> _showPasswordDialog() async {
     _showGenericPasswordDialog(
      context: context,
      passwordField: 'adminPassword',
      onSuccess: () => Navigator.of(context).pushNamed('/web_admin'),
    );
  }

  Future<void> _showBoardPasswordDialog(BuildContext context) async {
    _showGenericPasswordDialog(
      context: context,
      passwordField: 'boardPassword',
      onSuccess: () => Navigator.of(context).pushNamed('/admin_note'),
      title: 'Enter Board Password',
    );
  }

  Future<void> _showGenericPasswordDialog({
    required BuildContext context,
    required String passwordField,
    required VoidCallback onSuccess,
    String title = 'Enter Access Password',
  }) async {
    final passwordController = TextEditingController();
    String? correctPassword = '1234'; 
    
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      correctPassword = settingsDoc.data()?[passwordField] ?? ((passwordField == 'adminPassword') ? '1234' : '');
    } catch (e) {
      debugPrint("Error fetching password: $e");
    }

    if (!context.mounted) return;
    
    showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: Text(title, style: const TextStyle(color: Colors.white)),
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
                      onSuccess();
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
    final screenHeight = MediaQuery.of(context).size.height;
    
    Widget content = Center(
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
              Navigator.of(context).pushNamed('/guest');
            },
            isPrimary: true,
          ),
          const SizedBox(height: 20),
           StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('admin_settings')
                .snapshots(),
            builder: (context, snapshot) {
              String boardName = 'Admin Board';
              if (snapshot.hasData && snapshot.data != null) {
                 final data = snapshot.data!.data() as Map<String, dynamic>?;
                 boardName = data?['boardName'] ?? 'Admin Board';
              }
              return _buildButton(
                context,
                label: boardName,
                icon: Icons.dashboard,
                onPressed: () => _showBoardPasswordDialog(context),
                isPrimary: false, 
              );
            },
          ),
          
          // Web-specific Notice Area
          if (kIsWeb) ...[
            const SizedBox(height: 32),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('settings')
                  .doc('admin_settings')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == null) return const SizedBox.shrink();
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                final noticeContent = data?['noticePopupContent'] as String?;
                
                if (noticeContent == null || noticeContent.isEmpty) {
                  return const SizedBox.shrink();
                }

                return AnimatedBuilder(
                  animation: _rainbowController,
                  builder: (context, child) {
                    return Container(
                      width: 320,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: SweepGradient(
                          center: FractionalOffset.center,
                          colors: const [
                            Colors.redAccent, 
                            Colors.orangeAccent, 
                            Colors.yellowAccent, 
                            Colors.greenAccent, 
                            Colors.blueAccent, 
                            Colors.purpleAccent, 
                            Colors.redAccent
                          ],
                          stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
                          transform: GradientRotation(_rainbowController.value * 2 * math.pi),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(76),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          )
                        ]
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(Icons.campaign, color: Colors.blueAccent, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                noticeContent,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );

    // If web, apply the 10% upward shift
    if (kIsWeb) {
      content = Padding(
        padding: EdgeInsets.only(bottom: screenHeight * 0.20),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          content,
          // Hidden button at bottom left
          Positioned(
            left: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: () => _showPasswordDialog(),
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
