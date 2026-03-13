import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/router/app_router.dart';
import '../providers/notifications_provider.dart';

/// AppBar action: bell icon with unread-count badge.
/// Uses Riverpod to watch unread count from the notifications stream.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final theme  = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          icon:    const FaIcon(FontAwesomeIcons.bell, size: 18),
          tooltip: 'Notificaciones',
          onPressed: () => context.push(AppRoutes.notifications),
        ),
        if (unread > 0)
          Positioned(
            top:   10,
            right: 10,
            child: IgnorePointer(
              child: Container(
                width:  8,
                height: 8,
                decoration: BoxDecoration(
                  color:  theme.colorScheme.error,
                  shape:  BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
