import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'services/email_service.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    _messageController.clear();
    FocusScope.of(context).unfocus();

    try {
      final docRef = await _firestore
          .collection('chats')
          .doc('main_thread')
          .collection('messages')
          .add({
        'text': messageText,
        'senderType': 'PLAYER',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _handleNewMessageEmail(messageText, 'PLAYER', docRef.id);
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  Future<void> _handleNewMessageEmail(
      String messageText, String senderType, String messageId) async {
    try {
      final settingsDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin_settings')
          .get();
      final recipientEmail =
          settingsDoc.data()?['notificationEmail'] as String?;

      if (recipientEmail != null && recipientEmail.isNotEmpty) {
        final emailService = EmailService();
        await emailService.sendNewMessageEmail(
          recipientEmail: recipientEmail,
          senderType: senderType,
          messageText: messageText,
          messageId: messageId,
        );
      }
    } catch (e) {
      debugPrint('Error sending chat notification email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Chat'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc('main_thread')
                  .collection('messages')
                  .orderBy('timestamp')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final String text = messageData['text'] ?? '';
                    final String senderType =
                        messageData['senderType'] ?? 'PLAYER';
                    final Timestamp? timestamp = messageData['timestamp'];

                    final String timeString = timestamp != null
                        ? DateFormat('HH:mm').format(timestamp.toDate())
                        : '';

                    final bool isAdmin = senderType == 'ADMIN';

                    return Align(
                      alignment: isAdmin
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isAdmin
                              ? Colors.grey.shade300
                              : Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isAdmin
                              ? CrossAxisAlignment.start
                              : CrossAxisAlignment.end,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                  color:
                                      isAdmin ? Colors.black87 : Colors.white),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeString,
                              style: TextStyle(
                                color:
                                    isAdmin ? Colors.black54 : Colors.white70,
                                fontSize: 12,
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
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Enter a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (value) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
