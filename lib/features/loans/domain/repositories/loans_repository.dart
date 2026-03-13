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

  /// Registers a payment via `register_payment` RPC.
  /// Returns the new transaction ID from the database.
  Future<String> registerPayment({
    required String        loanId,
    required double        amount,
    required PaymentMethod paymentMethod,
    String?                notes,
    String?                operationId,
    String?                evidencePath,
    Map<String, dynamic>?  paymentMetadata,
  });

  /// Uploads payment evidence image to Supabase Storage.
  /// [localFilePath] is the path to the (compressed) local file.
  /// Returns the storage path used (e.g. `{loanId}/{uuid}.jpg`).
  Future<String> uploadPaymentEvidence({
    required String loanId,
    required String localFilePath,
  });

  /// Returns a signed URL (1 hour TTL) for viewing a stored evidence file.
  Future<String> getEvidenceUrl(String storagePath);

  // ── Search ─────────────────────────────────────────────────────
  Future<UserSearchResult> searchUserByPhone(String phone);

  // ── Server RPCs ────────────────────────────────────────────────
  Future<void>                   confirmTransaction(String transactionId);
  Future<void>                   disputeTransaction(String transactionId, {String? reason});
  Future<void>                   rejectTransaction(String transactionId, {String? reason});
  Future<Map<String, dynamic>>   getUserSummary();
  Future<Map<String, dynamic>>   getLoanWithTransactions(String loanId);

  /// Creditor sends an in-app payment request to the debtor.
  /// Throws if the debtor is an external contact (no Wayqui account).
  Future<void>                   requestPayment(String loanId);
}
