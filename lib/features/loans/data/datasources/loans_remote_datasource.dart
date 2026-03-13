import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/loan_transaction_entity.dart';
import '../../domain/entities/user_search_result.dart';

abstract class LoansRemoteDataSource {
  Future<List<LoanEntity>> getLoansAsCreditor(String userId);
  Future<List<LoanEntity>> getLoansAsDebtor(String userId);
  Future<LoanEntity>       getLoanById(String loanId);
  Future<LoanEntity>       createLoan(Map<String, dynamic> data);
  Future<List<LoanTransactionEntity>> getTransactions(String loanId);
  Future<Map<String, dynamic>>        registerPayment(Map<String, dynamic> params);
  Future<String>                      uploadPaymentEvidence(String loanId, String localFilePath);
  Future<String>                      getEvidenceUrl(String storagePath);
  Future<UserSearchResult>            searchUserByPhone(String phone);
  Future<void>                        confirmTransaction(String transactionId);
  Future<void>                        disputeTransaction(String transactionId, {String? reason});
  Future<void>                        rejectTransaction(String transactionId, {String? reason});
  Future<Map<String, dynamic>>        getUserSummary();
  Future<Map<String, dynamic>>        getLoanWithTransactions(String loanId);
  Future<void>                        requestPayment(String loanId);
}

class LoansRemoteDataSourceImpl implements LoansRemoteDataSource {
  final SupabaseClient _client;
  const LoansRemoteDataSourceImpl(this._client);

  static final _uuid = const Uuid();

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

  /// Calls the `register_payment` SECURITY DEFINER RPC.
  /// [params] keys match the RPC parameter names (p_loan_id, p_amount, etc.).
  @override
  Future<Map<String, dynamic>> registerPayment(
      Map<String, dynamic> params) async {
    debugPrint('[RPC] register_payment → params: $params');
    try {
      final r = await _client
          .rpc('register_payment', params: params)
          .timeout(const Duration(seconds: 20));
      debugPrint('[RPC] register_payment ← success: $r');
      return Map<String, dynamic>.from(r as Map);
    } on TimeoutException {
      debugPrint('[RPC] register_payment ← TIMEOUT (>20s)');
      throw Exception(
          'El servidor tardó demasiado. Verifica tu conexión e intenta de nuevo.');
    } on PostgrestException catch (e) {
      debugPrint('[RPC] register_payment ← PostgrestException '
          'code=${e.code} msg=${e.message} details=${e.details}');
      throw Exception(_rpcErrorMessage(e));
    } catch (e, st) {
      debugPrint('[RPC] register_payment ← ERROR: $e\n$st');
      throw Exception('Error al registrar el pago: $e');
    }
  }

  /// Uploads [localFilePath] bytes to the `payment_proofs` bucket.
  /// Storage path: `{loanId}/{uuid}.jpg`
  @override
  Future<String> uploadPaymentEvidence(
      String loanId, String localFilePath) async {
    final bytes = await File(localFilePath).readAsBytes();
    final storagePath = '$loanId/${_uuid.v4()}.jpg';
    debugPrint('[Storage] uploading ${bytes.length} bytes → '
        'payment_proofs/$storagePath');
    try {
      await _client.storage
          .from('payment_proofs')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: false),
          )
          .timeout(const Duration(seconds: 30));
      debugPrint('[Storage] upload OK → $storagePath');
      return storagePath;
    } on TimeoutException {
      debugPrint('[Storage] upload TIMEOUT (>30s)');
      throw Exception(
          'La subida del comprobante tardó demasiado. '
          'Verifica tu conexión e intenta de nuevo.');
    } on StorageException catch (e) {
      debugPrint('[Storage] StorageException '
          'statusCode=${e.statusCode} msg=${e.message} error=${e.error}');
      throw Exception(_storageErrorMessage(e));
    } catch (e, st) {
      debugPrint('[Storage] ERROR: $e\n$st');
      throw Exception('Error al subir el comprobante: $e');
    }
  }

  @override
  Future<String> getEvidenceUrl(String storagePath) =>
      _client.storage
          .from('payment_proofs')
          .createSignedUrl(storagePath, 3600);

  @override
  Future<UserSearchResult> searchUserByPhone(String phone) async {
    final result =
        await _client.rpc('search_user_by_phone', params: {'p_phone': phone});
    return UserSearchResult.fromJson(Map<String, dynamic>.from(result as Map));
  }

  @override
  Future<void> confirmTransaction(String transactionId) =>
      _client.rpc('confirm_transaction',
          params: {'p_transaction_id': transactionId});

  @override
  Future<void> disputeTransaction(String transactionId,
          {String? reason}) =>
      _client.rpc('dispute_transaction', params: {
        'p_transaction_id': transactionId,
        if (reason != null) 'p_reason': reason,
      });

  @override
  Future<void> rejectTransaction(String transactionId,
          {String? reason}) =>
      _client.rpc('reject_transaction', params: {
        'p_transaction_id': transactionId,
        if (reason != null) 'p_reason': reason,
      });

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

  @override
  Future<void> requestPayment(String loanId) =>
      _client.rpc('request_payment', params: {'p_loan_id': loanId});

  // ── Error message helpers ────────────────────────────────────────────────

  static String _rpcErrorMessage(PostgrestException e) {
    final code = e.code ?? '';
    final msg  = e.message.toLowerCase();
    if (code == 'PGRST301' || msg.contains('jwt')) {
      return 'Sesión expirada. Vuelve a iniciar sesión.';
    }
    if (code == '42501' || msg.contains('permission') || msg.contains('rls')) {
      return 'Sin permisos para registrar este pago.';
    }
    if (code == '23505' || msg.contains('unique') || msg.contains('duplicate')) {
      return 'Este N° de operación ya fue registrado.';
    }
    if (msg.contains('loan') && msg.contains('active')) {
      return 'El préstamo ya no está activo.';
    }
    return 'Error del servidor: ${e.message}';
  }

  static String _storageErrorMessage(StorageException e) {
    final status = e.statusCode ?? '';
    final msg    = e.message.toLowerCase();
    if (status == '403' || msg.contains('permission') || msg.contains('policy')) {
      return 'Sin permisos para subir el comprobante. '
          'Verifica que el bucket payment_proofs tenga RLS configurado.';
    }
    if (status == '404' || msg.contains('not found') || msg.contains('bucket')) {
      return 'El bucket de almacenamiento no existe. '
          'Crea el bucket payment_proofs en Supabase Storage.';
    }
    if (status == '413' || msg.contains('too large') || msg.contains('size')) {
      return 'El archivo es demasiado grande (máx. 10 MB).';
    }
    if (msg.contains('already exists') || msg.contains('duplicate')) {
      return 'Ya existe un comprobante con ese nombre. Intenta de nuevo.';
    }
    return 'Error de almacenamiento (${e.statusCode}): ${e.message}';
  }
}
