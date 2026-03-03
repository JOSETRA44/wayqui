import '../entities/loan_entity.dart';
import '../repositories/loans_repository.dart';

class GetLoansUseCase {
  final LoansRepository _repo;
  const GetLoansUseCase(this._repo);

  Future<({List<LoanEntity> asCreditor, List<LoanEntity> asDebtor})> call(
      String userId) async {
    final results = await Future.wait([
      _repo.getLoansAsCreditor(userId),
      _repo.getLoansAsDebtor(userId),
    ]);
    return (asCreditor: results[0], asDebtor: results[1]);
  }
}
