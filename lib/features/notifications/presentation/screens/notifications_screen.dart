import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/wayqui_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../domain/entities/notification_entity.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme          = Theme.of(context);
    final notifAsync     = ref.watch(notificationsStreamProvider);
    final uid            = ref.watch(authProvider).value?.id;
    final repo           = ref.read(notificationsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Notificaciones', style: theme.textTheme.headlineSmall),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.home),
        ),
        actions: [
          if (notifAsync.value?.any((n) => !n.isRead) == true)
            TextButton(
              onPressed: () async {
                if (uid == null) return;
                HapticFeedback.selectionClick();
                await repo.markAllRead(uid);
              },
              child: Text(
                'Marcar todo leído',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          const SizedBox(width: AppConstants.spacing8),
        ],
      ),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => _ErrorView(message: e.toString()),
        data:    (list) {
          if (list.isEmpty) return const _EmptyView();
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppConstants.spacing8),
            itemCount:     list.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
            itemBuilder: (context, i) {
              final n = list[i];
              return _NotificationTile(
                notification: n,
                onTap: () async {
                  HapticFeedback.selectionClick();
                  if (!n.isRead) {
                    await repo.markAsRead(n.id);
                  }
                  if (!context.mounted) return;
                  if (n.loanId != null) {
                    context.push(AppRoutes.loanDetailPath(n.loanId!));
                  }
                },
              ).animate().fadeIn(
                delay: Duration(milliseconds: i * 40),
                duration: 250.ms,
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback        onTap;
  const _NotificationTile({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final colors = theme.extension<WayquiColors>()!;
    final n      = notification;
    final unread = !n.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        color: unread
            ? theme.colorScheme.primary.withValues(alpha: 0.04)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacing16,
          vertical:   AppConstants.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _iconColor(n.type, colors).withValues(alpha: 0.12),
              ),
              child: Center(
                child: FaIcon(
                  _icon(n.type),
                  size:  16,
                  color: _iconColor(n.type, colors),
                ),
              ),
            ),
            const SizedBox(width: AppConstants.spacing12),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.65),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(n.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 10,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            // Chevron (only if tappable to loan)
            if (n.loanId != null)
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 2),
                child: FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size:  12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(NotificationType t) => switch (t) {
        NotificationType.paymentRegistered => FontAwesomeIcons.moneyBillWave,
        NotificationType.paymentConfirmed  => FontAwesomeIcons.circleCheck,
        NotificationType.paymentRejected   => FontAwesomeIcons.circleXmark,
        NotificationType.paymentDisputed   => FontAwesomeIcons.triangleExclamation,
        NotificationType.paymentRequested  => FontAwesomeIcons.handshake,
      };

  Color _iconColor(NotificationType t, WayquiColors colors) => switch (t) {
        NotificationType.paymentRegistered => colors.pending,
        NotificationType.paymentConfirmed  => colors.positive,
        NotificationType.paymentRejected   => colors.negative,
        NotificationType.paymentDisputed   => colors.negative,
        NotificationType.paymentRequested  => colors.pending,
      };

  String _formatDate(DateTime dt) {
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inHours   < 1)  return 'Hace ${diff.inMinutes} min';
    if (diff.inHours   < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays    < 7)  return 'Hace ${diff.inDays} días';
    return DateFormat('dd MMM yyyy', 'es').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / Error
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.bellSlash,
            size:  48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppConstants.spacing16),
          Text(
            'Sin notificaciones',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppConstants.spacing8),
          Text(
            'Aquí verás los pagos registrados,\nconfirmados y solicitudes.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(FontAwesomeIcons.triangleExclamation,
                size: 36, color: theme.colorScheme.error),
            const SizedBox(height: AppConstants.spacing16),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )),
          ],
        ),
      ),
    );
  }
}
