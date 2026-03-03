import 'package:wayqui/core/utils/checksum_util.dart';
import '../entities/loan_entity.dart';
import '../repositories/loans_repository.dart';

class CreateLoanParams {
  final String   creditorId;
  final String?  debtorId;
  final String?  debtorName;
  final String?  debtorPhone;
  final double   amount;
  final String   description;
  final DateTime? dueDate;

  const CreateLoanParams({
    required this.creditorId,
    this.debtorId,
    this.debtorName,
    this.debtorPhone,
    required this.amount,
    required this.description,
    this.dueDate,
  });
}

class CreateLoanUseCase {
  final LoansRepository _repo;
  const CreateLoanUseCase(this._repo);

  Future<LoanEntity> call(CreateLoanParams p) {
    final now = DateTime.now().toIso8601String();
    final checksum = ChecksumUtil.forLoan(
      creditorId:  p.creditorId,
      debtorId:    p.debtorId ?? p.debtorPhone ?? '',
      amount:      p.amount.toStringAsFixed(2),
      description: p.description,
      createdAt:   now,
    );

    return _repo.createLoan(
      creditorId:  p.creditorId,
      debtorId:    p.debtorId,
      debtorName:  p.debtorName,
      debtorPhone: p.debtorPhone,
      amount:      p.amount,
      description: p.description,
      checksum:    checksum,
      dueDate:     p.dueDate,
    );
  }
}
