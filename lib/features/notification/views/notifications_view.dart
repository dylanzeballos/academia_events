import 'package:flutter/material.dart';
import 'package:academia_events/core/utils/theme_extensions.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: context.cardBg,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 64,
              color: context.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones pendientes',
              style: TextStyle(
                color: context.textMuted,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}