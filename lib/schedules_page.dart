import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SchedulesPage extends StatelessWidget {
  const SchedulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: const SchedulesList(),
    );
  }
}

class SchedulesList extends StatelessWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const SchedulesList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('schedules')
          .orderBy('order')
          .snapshots(),
      builder: (context, snapshot) {
        // ... existing checks ...
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
              child: Text('No schedules found.',
                  style: TextStyle(color: Colors.grey)));
        }

        final scheduleDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: physics,
          shrinkWrap: shrinkWrap,
          itemCount: scheduleDocs.length,
          itemBuilder: (context, index) {
            final scheduleData =
                scheduleDocs[index].data() as Map<String, dynamic>;
            final String pageText = scheduleData['page'] ?? '';
            final String imageUrl = scheduleData['imageUrl'] ?? '';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.all(12.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (imageUrl.isNotEmpty)
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          heightFactor: 3,
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
                  if (pageText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        pageText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
    );
  }
}

