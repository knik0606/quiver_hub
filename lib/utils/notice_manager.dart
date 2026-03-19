import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/notice_popup_widget.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

class NoticeManager {
  static OverlayEntry? _overlayEntry;
  static bool _isShowing = false;

  static Future<void> checkAndShowNotice() async {
    if (_isShowing) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('admin_settings').get();
      if (!doc.exists) return;

      final data = doc.data()!;
      final noticeContent = data['noticePopupContent'] as String?;
      final noticeCount = data['noticePopupCount'] as int?;
      final noticeId = data['noticeId'] as String?;

      if (noticeContent == null || noticeContent.isEmpty || noticeCount == null || noticeCount <= 0 || noticeId == null || noticeId.isEmpty) {
        return; // No active notice or misconfigured
      }

      final prefs = await SharedPreferences.getInstance();
      
      final savedNoticeId = prefs.getString('currentNoticeId');
      int remainingViews = 0;

      if (savedNoticeId != noticeId) {
        // New notice, reset tracking
        await prefs.setString('currentNoticeId', noticeId);
        await prefs.setInt('noticeRemainingViews', noticeCount);
        remainingViews = noticeCount;
      } else {
        // Existing notice
        remainingViews = prefs.getInt('noticeRemainingViews') ?? 0;
      }

      if (remainingViews > 0) {
        _showPopup(noticeContent, () async {
          _closePopup();
          final currentViews = prefs.getInt('noticeRemainingViews') ?? 0;
          if (currentViews > 0) {
            await prefs.setInt('noticeRemainingViews', currentViews - 1);
          }
        });
      }
    } catch (e) {
      debugPrint('Error checking notice: $e');
    }
  }

  static void _showPopup(String content, VoidCallback onClose) {
    if (_overlayEntry != null) return;
    
    final overlayState = globalNavigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    _isShowing = true;
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.2, // 20% from top
          left: 0,
          right: 0,
          child: SafeArea(
            child: NoticePopupWidget(
              content: content,
              onTap: onClose,
            ),
          ),
        );
      },
    );

    overlayState.insert(_overlayEntry!);
  }

  static void _closePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}
