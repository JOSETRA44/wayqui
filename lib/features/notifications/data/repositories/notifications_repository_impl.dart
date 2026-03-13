import '../../domain/entities/notification_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsDataSource _ds;
  const NotificationsRepositoryImpl(this._ds);

  @override
  Stream<List<NotificationEntity>> watchNotifications(String userId) =>
      _ds.watchNotifications(userId);

  @override
  Future<void> markAsRead(String notificationId) =>
      _ds.markAsRead(notificationId);

  @override
  Future<void> markAllRead(String userId) => _ds.markAllRead(userId);
}
