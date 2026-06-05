import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: Color(0xFF25D366)),
          SizedBox(height: 16),
          Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF2F3F5))),
          SizedBox(height: 8),
          Text('Aucune notification', style: TextStyle(color: Color(0xFF8A9199))),
        ],
      ),
    );
  }
}
