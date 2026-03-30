import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'utils/launcher_helper.dart';
import 'widgets/web_compatible_image.dart';

class SchedulesPage extends StatelessWidget {
  const SchedulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: SchedulesList(),
    );
  }
}

class SchedulesList extends StatefulWidget {
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const SchedulesList({
    super.key,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<SchedulesList> createState() => _SchedulesListState();
}

class _SchedulesListState extends State<SchedulesList> {
  late Stream<QuerySnapshot> _schedulesStream;

  @override
  void initState() {
    super.initState();
    _schedulesStream = FirebaseFirestore.instance
        .collection('schedules')
        .orderBy('order')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _schedulesStream,
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
                Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 64),
                SizedBox(height: 16),
                Text(
                  'No schedules found.',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ],
            ),
          );
        }

        final scheduleDocs = snapshot.data!.docs;

        return ListView.builder(
          physics: widget.physics,
          shrinkWrap: widget.shrinkWrap,
          itemCount: scheduleDocs.length,
          itemBuilder: (context, index) {
            final scheduleData =
                scheduleDocs[index].data() as Map<String, dynamic>;
            final String pageText = scheduleData['page'] ?? '';
            final String imageUrl = scheduleData['imageUrl'] ?? '';

            return Card(
              color: const Color(0xFF1E1E1E),
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (imageUrl.isNotEmpty)
                    if (kIsWeb)
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                LauncherHelper.launch(imageUrl.trim()),
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('View Image'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 22),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(minHeight: 100),
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
