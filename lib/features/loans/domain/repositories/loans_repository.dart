import '../entities/loan_entity.dart';
import '../entities/loan_transaction_entity.dart';
import '../entities/user_search_result.dart';

abstract class LoansRepository {
  // ── Loans ──────────────────────────────────────────────────────
  Future<List<LoanEntity>> getLoansAsCreditor(String userId);
  Future<List<LoanEntity>> getLoansAsDebtor(String userId);
  Future<LoanEntity>       getLoanById(String loanId);
  Future<LoanEntity> createLoan({
    required String  creditorId,
    required String? debtorId,
    required String? debtorName,
    required String? debtorPhone,
    required double  amount,
    required String  description,
    required String  checksum,
    DateTime?        dueDate,
  });
  Future<void> cancelLoan(String loanId);

  // ── Transactions ───────────────────────────────────────────────
  Future<List<LoanTransactionEntity>> getTransactions(String loanId);
  Future<LoanTransactionEntity> registerPayment({
    required String        loanId,
    required String        payerId,
    required double        amount,
    required PaymentMethod paymentMethod,
    required String        checksum,
    String?                notes,
  });

  // ── Search ─────────────────────────────────────────────────────
  Future<UserSearchResult> searchUserByPhone(String phone);

  // ── Server RPC ─────────────────────────────────────────────────
  Future<void>                   confirmTransaction(String transactionId);
  Future<Map<String, dynamic>>   getUserSummary();
  Future<Map<String, dynamic>>   getLoanWithTransactions(String loanId);
}
