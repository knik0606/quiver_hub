import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart'; // Keep for other uses if needed, or remove if unused. Keeping for safety.
import 'utils/launcher_helper.dart';
import 'widgets/web_compatible_image.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: const NoticesList(),
    );
  }
}

class NoticesList extends StatelessWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const NoticesList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notices')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        // ... checks ...
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
              child: Text('No notices found.',
                  style: TextStyle(color: Colors.grey)));
        }

        final noticeDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: noticeDocs.length,
          itemBuilder: (context, index) {
            final noticeData =
                noticeDocs[index].data() as Map<String, dynamic>;
            final String pageNumber =
                noticeData['pageNumber'] ?? (index + 1).toString();
            final String content = noticeData['content'] ?? 'No content';
            final String imageUrl = noticeData['imageUrl'] ?? '';

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
                    Text(
                      '[$pageNumber] $content',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 16),
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

