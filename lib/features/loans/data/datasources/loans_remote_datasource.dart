import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';

abstract class LoansRemoteDataSource {
  Future<List<LoanEntity>> getLoansAsCreditor(String userId);
  Future<List<LoanEntity>> getLoansAsDebtor(String userId);
  Future<LoanEntity> createLoan(Map<String, dynamic> data);
  Future<List<LoanTransactionEntity>> getTransactions(String loanId);
  Future<LoanTransactionEntity> registerPayment(Map<String, dynamic> data);
  Future<void> confirmTransaction(String transactionId);
  Future<Map<String, dynamic>> getUserSummary();
}

class LoansRemoteDataSourceImpl implements LoansRemoteDataSource {
  final SupabaseClient _client;
  const LoansRemoteDataSourceImpl(this._client);

  @override
  Future<List<LoanEntity>> getLoansAsCreditor(String userId) async {
    final rows = await _client
        .from('loans')
        .select()
        .eq('creditor_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => LoanEntity.fromJson(r)).toList();
  }

  @override
  Future<List<LoanEntity>> getLoansAsDebtor(String userId) async {
    final rows = await _client
        .from('loans')
        .select()
        .eq('debtor_id', userId)
        .order('created_at', ascending: false);
    return rows.map((r) => LoanEntity.fromJson(r)).toList();
  }

  @override
  Future<LoanEntity> createLoan(Map<String, dynamic> data) async {
    final row = await _client.from('loans').insert(data).select().single();
    return LoanEntity.fromJson(row);
  }

  @override
  Future<List<LoanTransactionEntity>> getTransactions(String loanId) async {
    final rows = await _client
        .from('loan_transactions')
        .select()
        .eq('loan_id', loanId)
        .order('created_at', ascending: false);
    return rows.map((r) => LoanTransactionEntity.fromJson(r)).toList();
  }

  @override
  Future<LoanTransactionEntity> registerPayment(
      Map<String, dynamic> data) async {
    final row = await _client
        .from('loan_transactions')
        .insert(data)
        .select()
        .single();
    return LoanTransactionEntity.fromJson(row);
  }

  @override
  Future<void> confirmTransaction(String transactionId) async {
    // Usar RPC para que el trigger maneje la lógica atómica en el servidor
    await _client.rpc('confirm_transaction',
        params: {'p_transaction_id': transactionId});
  }

  @override
  Future<Map<String, dynamic>> getUserSummary() async {
    final result = await _client.rpc('get_user_summary');
    return Map<String, dynamic>.from(result as Map);
  }
}
