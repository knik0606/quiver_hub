import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'utils/launcher_helper.dart';
import 'widgets/web_compatible_image.dart';

class AdminNotePage extends StatelessWidget {
  const AdminNotePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('admin_settings').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
               return Text(snapshot.data?['boardName'] ?? 'Admin Note');
            }
            return const Text('Admin Note');
          },
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Sync Data (Admin)',
            onPressed: () => _handleRefresh(context),
          ),
        ],
      ),
      body: const AdminNoteList(),
    );
  }

  Future<void> _handleRefresh(BuildContext context) async {
    final passwordController = TextEditingController();
    String? correctPassword = '1234';

    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      correctPassword = settingsDoc.data()?['adminPassword'] ?? '1234';
    } catch (e) {
      debugPrint("Error fetching password: $e");
    }

    if (!context.mounted) return;

    showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Enter Admin Password', style: TextStyle(color: Colors.white)),
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
                      _syncData(context);
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

  Future<void> _syncData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Dialog(
          backgroundColor: Color(0xFF1E1E1E),
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Syncing data...", style: TextStyle(color: Colors.white)),
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
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced successfully!')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Sync error: ${e.code} - ${e.message}');
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: ${e.message}')),
        );
      }
    } catch (e) {
       if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    }
  }
}

class AdminNoteList extends StatelessWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const AdminNoteList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    // Assuming the sync function syncs 'AdminNote' sheet to 'admin_notes' collection
    // If not, this will be empty, but this is the logical implementation based on description.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_notes') 
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('No notes found.',
                  style: TextStyle(color: Colors.grey)));
        }

        final noteDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: noteDocs.length,
          itemBuilder: (context, index) {
            final noteData =
                noteDocs[index].data() as Map<String, dynamic>;
            // Assuming similar columns to Notices: Content, ImageUrl, etc.
            // The user said "Similar to Notices, Schedules content".
            final String content = noteData['content'] ?? 'No content';
            // C1 is 'BoardName', usually A/B columns are content. 
            // Notice structure: pageNumber, content, imageUrl.
            // We use 'content' and 'imageUrl' if present.
            final String imageUrl = noteData['imageUrl'] ?? '';
            final String title = noteData['title'] ?? ''; // Maybe a title?

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.all(12.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                         style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    if (title.isNotEmpty) const SizedBox(height: 8),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold, // Matches Notices style
                        color: Colors.white,
                      ),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      if (kIsWeb)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => LauncherHelper.launch(imageUrl.trim()),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('View Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 22),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: WebCompatibleImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
