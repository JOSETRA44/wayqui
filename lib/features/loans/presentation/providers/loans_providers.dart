import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/supabase_providers.dart';
import '../../data/datasources/loans_remote_datasource.dart';
import '../../data/repositories/loans_repository_impl.dart';
import '../../domain/entities/loan_entity.dart';
import '../../domain/usecases/create_loan_usecase.dart';
import '../../domain/usecases/get_loans_usecase.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';

// ─── Dependency graph ─────────────────────────────────────────────────────────

final _loansDataSourceProvider = Provider(
  (ref) => LoansRemoteDataSourceImpl(ref.watch(supabaseClientProvider)),
  name: 'loansDataSource',
);

final _loansRepositoryProvider = Provider(
  (ref) => LoansRepositoryImpl(ref.watch(_loansDataSourceProvider)),
  name: 'loansRepository',
);

// ─── Use case providers ───────────────────────────────────────────────────────

final _getLoansUseCaseProvider = Provider(
  (ref) => GetLoansUseCase(ref.watch(_loansRepositoryProvider)),
);

final _createLoanUseCaseProvider = Provider(
  (ref) => CreateLoanUseCase(ref.watch(_loansRepositoryProvider)),
);

// ─── User summary (balance) ───────────────────────────────────────────────────

final userSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final repo = ref.watch(_loansRepositoryProvider);
  return repo.getUserSummary();
});

// ─── Loans list (creditor + debtor) ──────────────────────────────────────────

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

    final useCase = ref.watch(_getLoansUseCaseProvider);
    return useCase(user.id);
  }

  Future<void> createLoan(CreateLoanParams params) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final useCase = ref.read(_createLoanUseCaseProvider);
      await useCase(params);
      return ref.read(_getLoansUseCaseProvider)(
          ref.read(authProvider).value!.id);
    });
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).value;
    if (user == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(_getLoansUseCaseProvider)(user.id),
    );
  }

  Future<void> confirmTransaction(String transactionId) async {
    final repo = ref.read(_loansRepositoryProvider);
    await repo.confirmTransaction(transactionId);
    ref.invalidateSelf(); // Recargar lista tras confirmar
  }
}
