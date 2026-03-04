import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';
import '../../domain/entities/user_search_result.dart';
import '../../domain/repositories/loans_repository.dart';
import '../datasources/loans_remote_datasource.dart';

class LoansRepositoryImpl implements LoansRepository {
  final LoansRemoteDataSource _ds;
  const LoansRepositoryImpl(this._ds);

  @override
  Future<List<LoanEntity>> getLoansAsCreditor(String userId) =>
      _ds.getLoansAsCreditor(userId);

  @override
  Future<List<LoanEntity>> getLoansAsDebtor(String userId) =>
      _ds.getLoansAsDebtor(userId);

  @override
  Future<LoanEntity> getLoanById(String loanId) =>
      _ds.getLoanById(loanId);

  @override
  Future<LoanEntity> createLoan({
    required String  creditorId,
    required String? debtorId,
    required String? debtorName,
    required String? debtorPhone,
    required double  amount,
    required String  description,
    required String  checksum,
    DateTime?        dueDate,
  }) =>
      _ds.createLoan({
        'creditor_id': creditorId,
        if (debtorId    != null) 'debtor_id':    debtorId,
        if (debtorName  != null) 'debtor_name':  debtorName,
        if (debtorPhone != null) 'debtor_phone': debtorPhone,
        'amount':      amount,
        'description': description,
        'checksum':    checksum,
        'currency':    'PEN',
        if (dueDate != null)
          'due_date': dueDate.toIso8601String().substring(0, 10),
      });

  @override
  Future<void> cancelLoan(String loanId) async {
    await _ds.createLoan({'id': loanId, 'status': 'cancelled'});
  }

  @override
  Future<List<LoanTransactionEntity>> getTransactions(String loanId) =>
      _ds.getTransactions(loanId);

  @override
  Future<LoanTransactionEntity> registerPayment({
    required String        loanId,
    required String        payerId,
    required double        amount,
    required PaymentMethod paymentMethod,
    required String        checksum,
    String?                notes,
  }) =>
      _ds.registerPayment({
        'loan_id':        loanId,
        'payer_id':       payerId,
        'amount':         amount,
        'payment_method': paymentMethod.value,
        'checksum':       checksum,
        if (notes != null) 'notes': notes,
      });

  @override
  Future<UserSearchResult> searchUserByPhone(String phone) =>
      _ds.searchUserByPhone(phone);

  @override
  Future<void> confirmTransaction(String transactionId) =>
      _ds.confirmTransaction(transactionId);

  @override
  Future<Map<String, dynamic>> getUserSummary() =>
      _ds.getUserSummary();

  @override
  Future<Map<String, dynamic>> getLoanWithTransactions(String loanId) =>
      _ds.getLoanWithTransactions(loanId);
}
