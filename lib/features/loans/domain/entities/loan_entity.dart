enum LoanStatus { active, partiallyPaid, paid, cancelled, disputed }

extension LoanStatusX on LoanStatus {
  String get label => switch (this) {
        LoanStatus.active        => 'Activo',
        LoanStatus.partiallyPaid => 'Parcial',
        LoanStatus.paid          => 'Pagado',
        LoanStatus.cancelled     => 'Cancelado',
        LoanStatus.disputed      => 'En disputa',
      };

  static LoanStatus fromString(String s) => switch (s) {
        'partially_paid' => LoanStatus.partiallyPaid,
        'paid'           => LoanStatus.paid,
        'cancelled'      => LoanStatus.cancelled,
        'disputed'       => LoanStatus.disputed,
        _                => LoanStatus.active,
      };
}

class LoanEntity {
  final String   id;
  final String   creditorId;
  final String?  debtorId;
  final String?  debtorName;
  final String?  debtorPhone;
  final double   amount;
  final double   remainingAmount;
  final String   currency;
  final String   description;
  final DateTime? dueDate;
  final LoanStatus status;
  final String   checksum;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LoanEntity({
    required this.id,
    required this.creditorId,
    this.debtorId,
    this.debtorName,
    this.debtorPhone,
    required this.amount,
    required this.remainingAmount,
    required this.currency,
    required this.description,
    this.dueDate,
    required this.status,
    required this.checksum,
    required this.createdAt,
    required this.updatedAt,
  });

  double get paidAmount => amount - remainingAmount;
  double get progressPercent => amount > 0 ? paidAmount / amount : 0;
  bool   get isFullyPaid    => remainingAmount == 0;
  bool   get isActive       => status == LoanStatus.active || status == LoanStatus.partiallyPaid;

  factory LoanEntity.fromJson(Map<String, dynamic> json) => LoanEntity(
        id:              json['id'] as String,
        creditorId:      json['creditor_id'] as String,
        debtorId:        json['debtor_id'] as String?,
        debtorName:      json['debtor_name'] as String?,
        debtorPhone:     json['debtor_phone'] as String?,
        amount:          (json['amount'] as num).toDouble(),
        remainingAmount: (json['remaining_amount'] as num).toDouble(),
        currency:        json['currency'] as String,
        description:     json['description'] as String,
        dueDate:         json['due_date'] != null
            ? DateTime.parse(json['due_date'] as String)
            : null,
        status:          LoanStatusX.fromString(json['status'] as String),
        checksum:        json['checksum'] as String,
        createdAt:       DateTime.parse(json['created_at'] as String),
        updatedAt:       DateTime.parse(json['updated_at'] as String),
      );
}
