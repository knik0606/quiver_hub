import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NoticesPage extends StatelessWidget {
  const NoticesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notices')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notices found.'));
          }

          final noticeDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: noticeDocs.length,
            itemBuilder: (context, index) {
              // ▼▼▼ 이 부분을 수정합니다 ▼▼▼
              final noticeData =
                  noticeDocs[index].data() as Map<String, dynamic>;
              final String pageNumber =
                  noticeData['pageNumber'] ?? (index + 1).toString();
              final String content = noticeData['content'] ?? 'No content';
              final String imageUrl = noticeData['imageUrl'] ?? '';

              return Card(
                margin: const EdgeInsets.all(12.0),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[$pageNumber] $content', // pageNumber와 content를 함께 표시
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // imageUrl이 비어있지 않을 때만 SizedBox와 Image를 표시
                      if (imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
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
                              // 에러 발생 시 아이콘 대신 빈 공간으로 처리하거나 다른 위젯을 넣을 수 있습니다.
                              return Container();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
              // ▲▲▲ 여기까지 수정 ▲▲▲
            },
          );
        },
      ),
    );
  }
}
