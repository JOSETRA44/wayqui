import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/notification_entity.dart';

class NotificationsDataSource {
  final SupabaseClient _client;
  const NotificationsDataSource(this._client);

  /// Realtime stream — emits a new list every time the notifications table
  /// changes for [userId]. Supabase's `.stream()` handles subscription
  /// lifecycle automatically when the stream is cancelled.
  Stream<List<NotificationEntity>> watchNotifications(String userId) =>
      _client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .map((rows) => rows
              .map((r) => NotificationEntity.fromJson(
                  Map<String, dynamic>.from(r)))
              .toList());

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
