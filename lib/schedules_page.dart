import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils/launcher_helper.dart';
import 'widgets/web_compatible_image.dart';

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
                  if (imageUrl.isNotEmpty)
                    if (kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: WebCompatibleImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.fitWidth,
                        ),
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

