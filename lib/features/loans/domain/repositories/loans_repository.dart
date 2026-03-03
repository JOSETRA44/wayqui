import '../entities/loan_entity.dart';
import '../entities/loan_transaction_entity.dart';

abstract class LoansRepository {
  // ── Loans ──────────────────────────────────────────────────────
  Future<List<LoanEntity>> getLoansAsCreditor(String userId);
  Future<List<LoanEntity>> getLoansAsDebtor(String userId);
  Future<LoanEntity> createLoan({
    required String creditorId,
    required String? debtorId,
    required String? debtorName,
    required String? debtorPhone,
    required double amount,
    required String description,
    required String checksum,
    DateTime? dueDate,
  });
  Future<void> cancelLoan(String loanId);

  // ── Transactions ───────────────────────────────────────────────
  Future<List<LoanTransactionEntity>> getTransactions(String loanId);
  Future<LoanTransactionEntity> registerPayment({
    required String loanId,
    required String payerId,
    required double amount,
    required PaymentMethod paymentMethod,
    required String checksum,
    String? notes,
  });

  // ── Server RPC ─────────────────────────────────────────────────
  Future<void> confirmTransaction(String transactionId);
  Future<Map<String, dynamic>> getUserSummary();
}
