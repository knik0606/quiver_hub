import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'utils/launcher_helper.dart';
import 'widgets/web_compatible_image.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: NoticesList(),
    );
  }
}

class NoticesList extends StatefulWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const NoticesList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<NoticesList> createState() => _NoticesListState();
}

class _NoticesListState extends State<NoticesList> {
  late Stream<QuerySnapshot> _noticesStream;

  @override
  void initState() {
    super.initState();
    _noticesStream = FirebaseFirestore.instance
        .collection('notices')
        .orderBy('order')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _noticesStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: Colors.blueAccent,
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign_outlined, color: Colors.grey, size: 64),
                SizedBox(height: 16),
                Text(
                  'No notices found.',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          );
        }

        final noticeDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          itemCount: noticeDocs.length,
          itemBuilder: (context, index) {
            final noticeData = noticeDocs[index].data() as Map<String, dynamic>;
            final String pageNumber =
                noticeData['pageNumber']?.toString() ?? (index + 1).toString();
            final String content = noticeData['content'] ?? 'No content';
            final String imageUrl = noticeData['imageUrl'] ?? '';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      if (kIsWeb)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                LauncherHelper.launch(imageUrl.trim()),
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
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 100),
                            width: double.infinity,
                            child: WebCompatibleImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.fitWidth,
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
