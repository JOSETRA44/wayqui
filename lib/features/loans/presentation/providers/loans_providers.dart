import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/loans_remote_datasource.dart';
import '../../data/repositories/loans_repository_impl.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/entities/user_search_result.dart';
import '../../domain/usecases/create_loan_usecase.dart';
import '../../domain/usecases/get_loans_usecase.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

// ─── Dependency graph ─────────────────────────────────────────────────────────

final _loansDataSourceProvider = Provider(
  (ref) => LoansRemoteDataSourceImpl(ref.watch(supabaseClientProvider)),
  name: 'loansDataSource',
);

final loansRepositoryProvider = Provider(
  (ref) => LoansRepositoryImpl(ref.watch(_loansDataSourceProvider)),
  name: 'loansRepository',
);

final _getLoansUseCaseProvider = Provider(
  (ref) => GetLoansUseCase(ref.watch(loansRepositoryProvider)),
);

final _createLoanUseCaseProvider = Provider(
  (ref) => CreateLoanUseCase(ref.watch(loansRepositoryProvider)),
);

// ─── User summary ─────────────────────────────────────────────────────────────

final userSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(loansRepositoryProvider).getUserSummary();
});

// ─── Loans list ───────────────────────────────────────────────────────────────

typedef LoansSnapshot = ({
  List<LoanEntity> asCreditor,
  List<LoanEntity> asDebtor,
});

final loansProvider =
    AsyncNotifierProvider.autoDispose<LoansNotifier, LoansSnapshot>(
  LoansNotifier.new,
);

class LoansNotifier extends AutoDisposeAsyncNotifier<LoansSnapshot> {
  @override
  Future<LoansSnapshot> build() async {
    final user = ref.watch(authProvider).value;
    if (user == null) {
      return (asCreditor: <LoanEntity>[], asDebtor: <LoanEntity>[]);
    }
    return ref.read(_getLoansUseCaseProvider)(user.id);
  }

  Future<void> createLoan(CreateLoanParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(_createLoanUseCaseProvider)(params);
      final uid = ref.read(authProvider).value!.id;
      return ref.read(_getLoansUseCaseProvider)(uid);
    });
  }

  Future<void> refresh() async {
    final uid = ref.read(authProvider).value?.id;
    if (uid == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(_getLoansUseCaseProvider)(uid));
  }

  Future<void> confirmTransaction(String transactionId) async {
    await ref.read(loansRepositoryProvider).confirmTransaction(transactionId);
    ref.invalidateSelf();
  }

  Future<void> disputeTransaction(String transactionId,
      {String? reason}) async {
    await ref
        .read(loansRepositoryProvider)
        .disputeTransaction(transactionId, reason: reason);
    ref.invalidateSelf();
  }

  Future<void> rejectTransaction(String transactionId,
      {String? reason}) async {
    await ref
        .read(loansRepositoryProvider)
        .rejectTransaction(transactionId, reason: reason);
    ref.invalidateSelf();
  }

  Future<void> requestPayment(String loanId) =>
      ref.read(loansRepositoryProvider).requestPayment(loanId);
}

// ─── Loan detail (by ID) ─────────────────────────────────────────────────────

final loanDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, loanId) => ref
      .watch(loansRepositoryProvider)
      .getLoanWithTransactions(loanId),
);

// ─── Evidence signed URL (1 h TTL) ────────────────────────────────────────────

final evidenceUrlProvider =
    FutureProvider.autoDispose.family<String, String>(
  (ref, storagePath) =>
      ref.watch(loansRepositoryProvider).getEvidenceUrl(storagePath),
);

// ─── Phone search (debounced) ─────────────────────────────────────────────────

final phoneSearchProvider = AsyncNotifierProvider.autoDispose<
    PhoneSearchNotifier, UserSearchResult?>(PhoneSearchNotifier.new);

class PhoneSearchNotifier
    extends AutoDisposeAsyncNotifier<UserSearchResult?> {
  Timer? _debounce;

  @override
  Future<UserSearchResult?> build() async {
    ref.onDispose(() => _debounce?.cancel());
    return null;
  }

  /// Búsqueda con debounce de 500 ms para no saturar el servidor.
  void search(String phone) {
    _debounce?.cancel();
    if (phone.replaceAll(RegExp(r'\s'), '').length < 9) {
      state = const AsyncData(null);
      return;
    }
    state = const AsyncLoading();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      state = await AsyncValue.guard(() =>
          ref.read(loansRepositoryProvider).searchUserByPhone(phone));
    });
  }

  void clear() {
    _debounce?.cancel();
    state = const AsyncData(null);
  }
}
