import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SchedulesPage extends StatelessWidget {
  const SchedulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('schedules')
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
            return const Center(child: Text('No schedules found.'));
          }

          final scheduleDocs = snapshot.data!.docs;

          // PageView를 ListView.builder로 변경
          return ListView.builder(
            itemCount: scheduleDocs.length,
            itemBuilder: (context, index) {
              final scheduleData =
                  scheduleDocs[index].data() as Map<String, dynamic>;
              final String pageText = scheduleData['page'] ?? '';
              final String imageUrl = scheduleData['imageUrl'] ?? '';

              // NoticesPage와 유사한 카드 UI
              return Card(
                margin: const EdgeInsets.all(12.0),
                elevation: 4,
                clipBehavior: Clip.antiAlias, // 이미지가 카드를 벗어나지 않도록
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 이미지가 있을 경우에만 표시
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            heightFactor: 3, // 로딩 중 높이 확보
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            height: 100,
                            child: Icon(Icons.error, color: Colors.red),
                          );
                        },
                      ),
                    // 텍스트가 있을 경우에만 표시
                    if (pageText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          pageText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
