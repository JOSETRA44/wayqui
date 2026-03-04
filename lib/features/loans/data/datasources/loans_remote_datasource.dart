import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';
import '../../domain/entities/user_search_result.dart';

abstract class LoansRemoteDataSource {
  Future<List<LoanEntity>> getLoansAsCreditor(String userId);
  Future<List<LoanEntity>> getLoansAsDebtor(String userId);
  Future<LoanEntity>       getLoanById(String loanId);
  Future<LoanEntity>       createLoan(Map<String, dynamic> data);
  Future<List<LoanTransactionEntity>> getTransactions(String loanId);
  Future<LoanTransactionEntity>       registerPayment(Map<String, dynamic> data);
  Future<UserSearchResult>            searchUserByPhone(String phone);
  Future<void>                        confirmTransaction(String transactionId);
  Future<Map<String, dynamic>>        getUserSummary();
  Future<Map<String, dynamic>>        getLoanWithTransactions(String loanId);
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
        .inFilter('status', ['active', 'partially_paid', 'paid'])
        .order('created_at', ascending: false);
    return rows.map(LoanEntity.fromJson).toList();
  }

  @override
  Future<List<LoanEntity>> getLoansAsDebtor(String userId) async {
    final rows = await _client
        .from('loans')
        .select()
        .eq('debtor_id', userId)
        .inFilter('status', ['active', 'partially_paid', 'paid'])
        .order('created_at', ascending: false);
    return rows.map(LoanEntity.fromJson).toList();
  }

  @override
  Future<LoanEntity> getLoanById(String loanId) async {
    final row = await _client
        .from('loans')
        .select()
        .eq('id', loanId)
        .single();
    return LoanEntity.fromJson(row);
  }

  @override
  Future<LoanEntity> createLoan(Map<String, dynamic> data) async {
    final row = await _client
        .from('loans')
        .insert(data)
        .select()
        .single();
    return LoanEntity.fromJson(row);
  }

  @override
  Future<List<LoanTransactionEntity>> getTransactions(String loanId) async {
    final rows = await _client
        .from('loan_transactions')
        .select()
        .eq('loan_id', loanId)
        .order('created_at', ascending: false);
    return rows.map(LoanTransactionEntity.fromJson).toList();
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
  Future<UserSearchResult> searchUserByPhone(String phone) async {
    final result = await _client
        .rpc('search_user_by_phone', params: {'p_phone': phone});
    return UserSearchResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<void> confirmTransaction(String transactionId) =>
      _client.rpc('confirm_transaction',
          params: {'p_transaction_id': transactionId});

  @override
  Future<Map<String, dynamic>> getUserSummary() async {
    final r = await _client.rpc('get_user_summary');
    return Map<String, dynamic>.from(r as Map);
  }

  @override
  Future<Map<String, dynamic>> getLoanWithTransactions(String loanId) async {
    final r = await _client.rpc('get_loan_with_transactions',
        params: {'p_loan_id': loanId});
    return Map<String, dynamic>.from(r as Map);
  }
}
