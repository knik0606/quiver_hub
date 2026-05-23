import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils/sync_helper.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _athleteNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _appTitleController = TextEditingController();
  final _adminBoardNameController = TextEditingController();
  final _adminBoardPasswordController = TextEditingController();
  final _noticePopupContentController = TextEditingController();
  final _noticePopupCountController = TextEditingController();
  final _telegramBotTokenController = TextEditingController();
  final _telegramChatIdController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String _notificationMethod = 'telegram';
  bool _isTelegramEditing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await _firestore.collection('settings').doc('admin_settings').get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _appTitleController.text = data['appTitle'] ?? '';
          _emailController.text = data['notificationEmail'] ?? '';
          _passwordController.text = data['adminPassword'] ?? '';
          _adminBoardNameController.text = data['boardName'] ?? '';
          _adminBoardPasswordController.text = data['boardPassword'] ?? '';
          _noticePopupContentController.text = data['noticePopupContent'] ?? '';
          _noticePopupCountController.text = (data['noticePopupCount'] ?? 0).toString();
          _notificationMethod = data['notificationMethod'] ?? 'telegram';
          _telegramBotTokenController.text = data['telegramBotToken'] ?? '';
          _telegramChatIdController.text = data['telegramChatId'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _addAthlete() {
    final name = _athleteNameController.text;
    if (name.isNotEmpty) {
      _firestore.collection('athletes').add({
        'name': name,
        'status': 'OUT',
      });
      _athleteNameController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added successfully.')),
      );
    }
  }

  void _deleteAthlete(String docId) {
    _firestore.collection('athletes').doc(docId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Athlete deleted.')),
    );
  }

  void _deleteAllMessages() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete All Messages?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all chat messages. Are you sure?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    ) ?? false;

    if (confirm) {
      final messagesRef = _firestore.collection('chats').doc('main_thread').collection('messages');
      final snapshots = await messagesRef.get();
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All messages deleted.')));
      }
    }
  }

  void _saveSettings() {
    final email = _emailController.text;
    final password = _passwordController.text;
    final appTitle = _appTitleController.text;
    final boardName = _adminBoardNameController.text;
    final boardPassword = _adminBoardPasswordController.text;
    final noticeContent = _noticePopupContentController.text;
    final noticeCount = int.tryParse(_noticePopupCountController.text) ?? 0;

    final settingsDoc = _firestore.collection('settings').doc('admin_settings');

    final Map<String, dynamic> settingsToUpdate = {};
    if (appTitle.isNotEmpty) {
      settingsToUpdate['appTitle'] = appTitle;
    }
    if (email.isNotEmpty) {
      settingsToUpdate['notificationEmail'] = email;
    }
    if (password.isNotEmpty) {
      settingsToUpdate['adminPassword'] = password;
    }
    if (boardName.isNotEmpty) {
      settingsToUpdate['boardName'] = boardName;
    }
    if (boardPassword.isNotEmpty) {
      settingsToUpdate['boardPassword'] = boardPassword;
    }
    settingsToUpdate['notificationMethod'] = _notificationMethod;
    settingsToUpdate['noticePopupContent'] = noticeContent;
    settingsToUpdate['noticePopupCount'] = noticeCount;
    
    // Update noticeId so clients know a new notice is available, if we are actually setting it.
    // If we only edit text, it still updates the ID to trigger a reset on the client sides.
    if (noticeContent.isNotEmpty && noticeCount > 0) {
      settingsToUpdate['noticeId'] = DateTime.now().millisecondsSinceEpoch.toString();
    } else {
      settingsToUpdate['noticeId'] = '';
    }

    if (settingsToUpdate.isNotEmpty) {
      settingsDoc.set(settingsToUpdate, SetOptions(merge: true));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved.')),
      );
      _appTitleController.clear();
      _emailController.clear();
      _passwordController.clear();
      _adminBoardNameController.clear();
      _adminBoardPasswordController.clear();
      _noticePopupContentController.clear();
      _noticePopupCountController.clear();
      
      // Reload to show saved values (optional, but good for feedback)
      _loadSettings();
    }
  }

  Future<void> _saveTelegramSettings() async {
    final token = _telegramBotTokenController.text.trim();
    final chatId = _telegramChatIdController.text.trim();
    if (token.isEmpty || chatId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bot Token과 Chat ID를 모두 입력해주세요.')),
      );
      return;
    }
    await _firestore.collection('settings').doc('admin_settings').set(
      {'telegramBotToken': token, 'telegramChatId': chatId},
      SetOptions(merge: true),
    );
    if (mounted) {
      setState(() => _isTelegramEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Telegram 설정이 저장됐습니다.')),
      );
    }
  }

  Future<void> _syncData() async {
    await SyncHelper.syncData(
      context, 
      onLoading: (isLoading) {
        if (mounted) {
          setState(() {
            _isLoading = isLoading;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(color: Colors.white);
    const inputDecoration = InputDecoration(
      labelStyle: TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white54),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueAccent),
      ),
      border: OutlineInputBorder(),
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manage Athletes',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _athleteNameController,
                        style: textStyle,
                        decoration: inputDecoration.copyWith(labelText: 'Athlete Name'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add),
                      onPressed: _addAthlete,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Current Athletes:', style: textStyle),
                StreamBuilder<QuerySnapshot>(
                  stream: _firestore.collection('athletes').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const CircularProgressIndicator();
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var athlete = snapshot.data!.docs[index];
                        return ListTile(
                          title: Text(athlete['name'], style: textStyle),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteAthlete(athlete.id),
                          ),
                        );
                      },
                    );
                  },
                ),
                const Divider(height: 40, color: Colors.white24),
                Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _appTitleController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'App Title'),
                ),
                const SizedBox(height: 16),
                const Text('Notification Method', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'telegram',
                      icon: Icon(Icons.send),
                      label: Text('Telegram'),
                    ),
                    ButtonSegment(
                      value: 'email',
                      icon: Icon(Icons.email_outlined),
                      label: Text('Email'),
                    ),
                  ],
                  selected: {_notificationMethod},
                  onSelectionChanged: (val) => setState(() => _notificationMethod = val.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Notification Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'New Admin Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                const Divider(height: 1, color: Colors.white24),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Telegram Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    _isTelegramEditing
                        ? Row(
                            children: [
                              TextButton(
                                onPressed: () => setState(() => _isTelegramEditing = false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                              ),
                              ElevatedButton(
                                onPressed: _saveTelegramSettings,
                                child: const Text('Save'),
                              ),
                            ],
                          )
                        : IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                            tooltip: 'Edit Telegram Settings',
                            onPressed: () => setState(() => _isTelegramEditing = true),
                          ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '📌 Telegram 봇 알림 설정\n'
                    '• Bot Token: BotFather에서 /newbot 으로 발급\n'
                    '• Chat ID: 봇에게 메시지 전송 후 getUpdates API로 확인\n'
                    '• 현재 봇: @QuiverHub_notify_bot\n'
                    '• 알림 방식을 Telegram으로 선택 시 이 정보가 사용됩니다',
                    style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.6),
                  ),
                ),
                const SizedBox(height: 12),
                AbsorbPointer(
                  absorbing: !_isTelegramEditing,
                  child: Opacity(
                    opacity: _isTelegramEditing ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        TextField(
                          controller: _telegramBotTokenController,
                          style: textStyle,
                          obscureText: !_isTelegramEditing,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Bot Token',
                            suffixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 16),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _telegramChatIdController,
                          style: textStyle,
                          decoration: inputDecoration.copyWith(
                            labelText: 'Chat ID',
                            suffixIcon: const Icon(Icons.lock_outline, color: Colors.white38, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 40, color: Colors.white24),
                Text('Notice Popup Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _noticePopupContentController,
                  style: textStyle,
                  maxLines: 2,
                  decoration: inputDecoration.copyWith(labelText: 'Notice Popup Content (Clear to disable)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _noticePopupCountController,
                  style: textStyle,
                  keyboardType: TextInputType.number,
                  decoration: inputDecoration.copyWith(labelText: 'Popup Display Count'),
                ),
                const Divider(height: 40, color: Colors.white24),
                Text('Admin Note Page Configuration', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminBoardNameController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Admin Board Name (Button Title)'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminBoardPasswordController,
                  style: textStyle,
                  decoration: inputDecoration.copyWith(labelText: 'Admin Board Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveSettings,
                        child: const Text('Save Settings'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filled(
                      icon: const Icon(Icons.download),
                      tooltip: 'Load Content from Google Drive',
                      onPressed: _syncData,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(height: 40, color: Colors.white24),
                Text('Data Management', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteAllMessages,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All Chat Messages'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withAlpha(50),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text("Syncing data...", style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
