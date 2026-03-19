import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MessagePage extends StatefulWidget {
  final bool isAdmin;
  const MessagePage({super.key, this.isAdmin = false});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final _messageController = TextEditingController();
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    FocusScope.of(context).unfocus();

    try {
      // Save the message to Firestore
      await FirebaseFirestore.instance
          .collection('chats')
          .doc('main_thread')
          .collection('messages')
          .add({
        'text': messageText,
        'senderType': widget.isAdmin ? 'ADMIN' : 'PLAYER',
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _messageController.clear();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Chat'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .doc('main_thread')
                    .collection('messages')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet. Say hi!', style: TextStyle(color: Colors.grey)),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final data = messages[index].data() as Map<String, dynamic>;
                      final String text = data['text'] ?? '';
                      final String senderType = data['senderType'] ?? 'PLAYER';
                      final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                      
                      final bool isAdminMsg = senderType == 'ADMIN';

                      return Align(
                        alignment: isAdminMsg ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: isAdminMsg ? Colors.blueAccent.withValues(alpha: 0.2) : const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(16).copyWith(
                                bottomRight: isAdminMsg ? Radius.zero : const Radius.circular(16),
                                bottomLeft: !isAdminMsg ? Radius.zero : const Radius.circular(16),
                              ),
                              border: Border.all(
                                color: isAdminMsg ? Colors.blue.withValues(alpha: 0.5) : Colors.transparent,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: isAdminMsg ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isAdminMsg ? 'Coach' : 'Player',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isAdminMsg ? Colors.blueAccent : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                if (timestamp != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('hh:mm a').format(timestamp.toDate()),
                                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              color: const Color(0xFF1E1E1E),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onSubmitted: (_) => _isSending ? null : _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.blueAccent,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendMessage,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
