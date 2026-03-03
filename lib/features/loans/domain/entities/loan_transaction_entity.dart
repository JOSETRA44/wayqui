enum PaymentMethod { yape, plin, cash, bankTransfer, other }
enum TransactionStatus { pending, confirmed, rejected }

extension PaymentMethodX on PaymentMethod {
  String get value => switch (this) {
        PaymentMethod.yape         => 'yape',
        PaymentMethod.plin         => 'plin',
        PaymentMethod.cash         => 'cash',
        PaymentMethod.bankTransfer => 'bank_transfer',
        PaymentMethod.other        => 'other',
      };

  String get label => switch (this) {
        PaymentMethod.yape         => 'Yape',
        PaymentMethod.plin         => 'Plin',
        PaymentMethod.cash         => 'Efectivo',
        PaymentMethod.bankTransfer => 'Transferencia',
        PaymentMethod.other        => 'Otro',
      };

  static PaymentMethod fromString(String s) => switch (s) {
        'plin'          => PaymentMethod.plin,
        'cash'          => PaymentMethod.cash,
        'bank_transfer' => PaymentMethod.bankTransfer,
        'other'         => PaymentMethod.other,
        _               => PaymentMethod.yape,
      };
}

class LoanTransactionEntity {
  final String            id;
  final String            loanId;
  final String            payerId;
  final double            amount;
  final PaymentMethod     paymentMethod;
  final TransactionStatus status;
  final String?           notes;
  final String            checksum;
  final DateTime          createdAt;
  final DateTime?         confirmedAt;
  final DateTime?         rejectedAt;
  final String?           confirmedBy;
  final String?           rejectionReason;

  const LoanTransactionEntity({
    required this.id,
    required this.loanId,
    required this.payerId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.notes,
    required this.checksum,
    required this.createdAt,
    this.confirmedAt,
    this.rejectedAt,
    this.confirmedBy,
    this.rejectionReason,
  });

  factory LoanTransactionEntity.fromJson(Map<String, dynamic> json) =>
      LoanTransactionEntity(
        id:             json['id'] as String,
        loanId:         json['loan_id'] as String,
        payerId:        json['payer_id'] as String,
        amount:         (json['amount'] as num).toDouble(),
        paymentMethod:  PaymentMethodX.fromString(json['payment_method'] as String),
        status:         switch (json['status'] as String) {
          'confirmed' => TransactionStatus.confirmed,
          'rejected'  => TransactionStatus.rejected,
          _           => TransactionStatus.pending,
        },
        notes:           json['notes'] as String?,
        checksum:        json['checksum'] as String,
        createdAt:       DateTime.parse(json['created_at'] as String),
        confirmedAt:     json['confirmed_at'] != null
            ? DateTime.parse(json['confirmed_at'] as String)
            : null,
        rejectedAt:      json['rejected_at'] != null
            ? DateTime.parse(json['rejected_at'] as String)
            : null,
        confirmedBy:     json['confirmed_by'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
      );
}
