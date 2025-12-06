import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.grey[800],
                              child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: Colors.white54)),
                            );
                          },
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

