enum NotificationType {
  paymentRegistered,
  paymentConfirmed,
  paymentRejected,
  paymentDisputed,
  paymentRequested,
}

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
        NotificationType.paymentRegistered => 'Pago registrado',
        NotificationType.paymentConfirmed  => 'Pago confirmado',
        NotificationType.paymentRejected   => 'Pago rechazado',
        NotificationType.paymentDisputed   => 'Pago en disputa',
        NotificationType.paymentRequested  => 'Solicitud de pago',
      };

  static NotificationType fromString(String s) => switch (s) {
        'payment_confirmed'  => NotificationType.paymentConfirmed,
        'payment_rejected'   => NotificationType.paymentRejected,
        'payment_disputed'   => NotificationType.paymentDisputed,
        'payment_requested'  => NotificationType.paymentRequested,
        _                    => NotificationType.paymentRegistered,
      };
}

class NotificationEntity {
  final String           id;
  final String           userId;
  final String           title;
  final String           body;
  final NotificationType type;
  final String?          loanId;
  final String?          transactionId;
  final bool             isRead;
  final DateTime         createdAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.loanId,
    this.transactionId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> j) =>
      NotificationEntity(
        id:            j['id'] as String,
        userId:        j['user_id'] as String,
        title:         j['title'] as String,
        body:          j['body'] as String,
        type:          NotificationTypeX.fromString(j['type'] as String),
        loanId:        j['loan_id'] as String?,
        transactionId: j['transaction_id'] as String?,
        isRead:        j['is_read'] as bool,
        createdAt:     DateTime.parse(j['created_at'] as String),
      );

  NotificationEntity copyWith({bool? isRead}) => NotificationEntity(
        id:            id,
        userId:        userId,
        title:         title,
        body:          body,
        type:          type,
        loanId:        loanId,
        transactionId: transactionId,
        isRead:        isRead ?? this.isRead,
        createdAt:     createdAt,
      );
}
