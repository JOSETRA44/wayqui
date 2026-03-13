enum PaymentMethod { yape, plin, cash, bankTransfer, other }
enum TransactionStatus { pending, confirmed, rejected, disputed }

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

extension TransactionStatusX on TransactionStatus {
  String get label => switch (this) {
        TransactionStatus.pending   => 'Pendiente',
        TransactionStatus.confirmed => 'Confirmado',
        TransactionStatus.rejected  => 'Rechazado',
        TransactionStatus.disputed  => 'En disputa',
      };

  bool get isTerminal =>
      this == TransactionStatus.confirmed ||
      this == TransactionStatus.rejected;

  bool get isPending => this == TransactionStatus.pending;

  static TransactionStatus fromString(String s) => switch (s) {
        'confirmed' => TransactionStatus.confirmed,
        'rejected'  => TransactionStatus.rejected,
        'disputed'  => TransactionStatus.disputed,
        _           => TransactionStatus.pending,
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
  final DateTime?         disputedAt;
  final String?           confirmedBy;
  final String?           rejectionReason;
  // ── New fields (Iteration 1) ──────────────────────────────────
  final String?           operationId;      // Yape/Plin operation number
  final String?           evidencePath;     // Supabase Storage path
  final Map<String, dynamic>? paymentMetadata; // { ocr_amount, ocr_operation_id }
  final String?           disputeReason;

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
    this.disputedAt,
    this.confirmedBy,
    this.rejectionReason,
    this.operationId,
    this.evidencePath,
    this.paymentMetadata,
    this.disputeReason,
  });

  bool get hasEvidence => evidencePath != null;

  factory LoanTransactionEntity.fromJson(Map<String, dynamic> json) =>
      LoanTransactionEntity(
        id:              json['id'] as String,
        loanId:          json['loan_id'] as String,
        payerId:         json['payer_id'] as String,
        amount:          (json['amount'] as num).toDouble(),
        paymentMethod:   PaymentMethodX.fromString(json['payment_method'] as String),
        status:          TransactionStatusX.fromString(json['status'] as String),
        notes:           json['notes'] as String?,
        checksum:        json['checksum'] as String,
        createdAt:       DateTime.parse(json['created_at'] as String),
        confirmedAt:     json['confirmed_at'] != null
            ? DateTime.parse(json['confirmed_at'] as String) : null,
        rejectedAt:      json['rejected_at'] != null
            ? DateTime.parse(json['rejected_at'] as String) : null,
        disputedAt:      json['disputed_at'] != null
            ? DateTime.parse(json['disputed_at'] as String) : null,
        confirmedBy:     json['confirmed_by'] as String?,
        rejectionReason: json['rejection_reason'] as String?,
        operationId:     json['operation_id'] as String?,
        evidencePath:    json['evidence_path'] as String?,
        paymentMetadata: json['payment_metadata'] as Map<String, dynamic>?,
        disputeReason:   json['dispute_reason'] as String?,
      );
}
