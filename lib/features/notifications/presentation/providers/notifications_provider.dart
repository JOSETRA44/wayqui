import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../data/datasources/notifications_datasource.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';

// ─── Dependency graph ─────────────────────────────────────────────────────────

final _notificationsDataSourceProvider = Provider(
  (ref) => NotificationsDataSource(ref.watch(supabaseClientProvider)),
  name: 'notificationsDataSource',
);

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepositoryImpl(
      ref.watch(_notificationsDataSourceProvider)),
  name: 'notificationsRepository',
);

// ─── Realtime stream ──────────────────────────────────────────────────────────

/// Emits the full notifications list in real-time via Supabase Realtime.
/// Returns an empty stream when the user is not authenticated.
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationEntity>>((ref) {
  final uid = ref.watch(authProvider).value?.id;
  if (uid == null) return const Stream.empty();
  return ref
      .watch(notificationsRepositoryProvider)
      .watchNotifications(uid);
});

// ─── Derived: unread count ────────────────────────────────────────────────────

/// Synchronously derived from the stream — no extra network call.
final unreadCountProvider = Provider.autoDispose<int>((ref) {
  return ref
          .watch(notificationsStreamProvider)
          .value
          ?.where((n) => !n.isRead)
          .length ??
      0;
});
