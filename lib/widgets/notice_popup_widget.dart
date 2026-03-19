import 'dart:math';
import 'package:flutter/material.dart';

class NoticePopupWidget extends StatefulWidget {
  final String content;
  final VoidCallback onTap;

  const NoticePopupWidget({
    super.key,
    required this.content,
    required this.onTap,
  });

  @override
  State<NoticePopupWidget> createState() => _NoticePopupWidgetState();
}

class _NoticePopupWidgetState extends State<NoticePopupWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(3), // thickness of the border
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: SweepGradient(
                   center: FractionalOffset.center,
                   colors: const [
                     Colors.redAccent, 
                     Colors.orangeAccent, 
                     Colors.yellowAccent, 
                     Colors.greenAccent, 
                     Colors.blueAccent, 
                     Colors.purpleAccent, 
                     Colors.redAccent
                   ],
                   stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
                   transform: GradientRotation(_controller.value * 2 * pi),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(76),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  )
                ]
              ),
              child: child,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13), // inner radius
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(Icons.campaign, color: Colors.blueAccent, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.content,
                    style: const TextStyle(
                       color: Colors.black87,
                       fontSize: 16,
                       fontWeight: FontWeight.w600,
                       height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.close, color: Colors.black38, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
