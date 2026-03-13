import '../entities/notification_entity.dart';

abstract class NotificationsRepository {
  Stream<List<NotificationEntity>> watchNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllRead(String userId);
}
