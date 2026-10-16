import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/utils/usecase.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/domain/validators.dart';
import '../entities/visit_entities.dart';
import '../repositories/visit_repository.dart';

class GetHosts implements UseCase<List<Host>, NoParams> {
  const GetHosts(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<List<Host>>> call(NoParams params) => _repo.getHosts();
}

/// Returning-visitor suggestions. Needs at least 4 digits, like the web.
class SearchVisitors implements UseCase<List<VisitorProfile>, String> {
  const SearchVisitors(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<List<VisitorProfile>>> call(String query) async {
    final q = query.trim();
    if (q.replaceAll(RegExp(r'\D'), '').length < 4) return const Success([]);
    return _repo.searchVisitors(q);
  }
}

class CheckBlacklist implements UseCase<BlacklistEntry?, ({String? phone, String? idNumber})> {
  const CheckBlacklist(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<BlacklistEntry?>> call(({String? phone, String? idNumber}) params) async {
    final phone = params.phone != null && Validators.isBdPhone(params.phone!) ? params.phone : null;
    final id = params.idNumber?.trim().isEmpty ?? true ? null : params.idNumber!.trim();
    if (phone == null && id == null) return const Success(null);
    return _repo.checkBlacklist(phone: phone, idNumber: id);
  }
}

class GetVisits implements UseCase<Paged<Visit>, VisitQuery> {
  const GetVisits(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Paged<Visit>>> call(VisitQuery query) => _repo.getVisits(query);
}

class GetVisit implements UseCase<Visit, int> {
  const GetVisit(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(int id) => _repo.getVisit(id);
}

class LookupVisit implements UseCase<Visit, String> {
  const LookupVisit(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(String code) async {
    final c = code.trim();
    if (c.isEmpty) return const Error(ServerFailure('Enter a visit code'));
    return _repo.lookup(c);
  }
}

/// RFID check-in needs a card number (same rule as the server).
Failure? _rfidCardRule(CheckinMethod method, String? cardNo) =>
    method == CheckinMethod.rfid && (cardNo == null || cardNo.trim().isEmpty)
    ? const ServerFailure(
        'Validation failed',
        statusCode: 422,
        errors: {
          'card_no': ['RFID card number is required for RFID check-in'],
        },
      )
    : null;

class CheckInWalkIn implements UseCase<Visit, WalkInCheckin> {
  const CheckInWalkIn(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(WalkInCheckin request) async {
    final rule = _rfidCardRule(request.method, request.details.cardNo);
    if (rule != null) return Error(rule);
    return _repo.checkInWalkIn(request);
  }
}

class CheckInExisting implements UseCase<Visit, ExistingCheckin> {
  const CheckInExisting(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(ExistingCheckin request) async {
    final rule = _rfidCardRule(request.method, request.cardNo);
    if (rule != null) return Error(rule);
    return _repo.checkInExisting(request);
  }
}

/// Pre-register a new visit, or edit one when [id] is given.
class SaveVisit implements UseCase<Visit, ({int? id, VisitForm form})> {
  const SaveVisit(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(({int? id, VisitForm form}) params) =>
      params.id == null ? _repo.preregister(params.form) : _repo.update(params.id!, params.form);
}

class GetActiveVisits implements UseCase<List<Visit>, NoParams> {
  const GetActiveVisits(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<List<Visit>>> call(NoParams params) => _repo.activeVisits();
}

class CheckoutByCode implements UseCase<Visit, String> {
  const CheckoutByCode(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(String code) async {
    final c = code.trim();
    if (c.isEmpty) return const Error(ServerFailure('Enter a visit code or card number'));
    return _repo.checkoutByCode(c);
  }
}

class DeleteVisit implements UseCase<void, int> {
  const DeleteVisit(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<void>> call(int id) => _repo.delete(id);
}

class GetVisitStatusCounts implements UseCase<Map<VisitStatus, int>, VisitQuery> {
  const GetVisitStatusCounts(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Map<VisitStatus, int>>> call(VisitQuery query) => _repo.statusCounts(query);
}

class DecideVisit implements UseCase<Visit, ({int id, VisitDecision decision, String? remarks})> {
  const DecideVisit(this._repo);

  final VisitRepository _repo;

  @override
  Future<Result<Visit>> call(({int id, VisitDecision decision, String? remarks}) params) =>
      _repo.decide(params.id, params.decision, remarks: params.remarks);
}
