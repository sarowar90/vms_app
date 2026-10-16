import '../../../../core/utils/guard.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../domain/entities/visit_entities.dart';
import '../../domain/repositories/visit_repository.dart';
import '../datasources/visit_remote_data_source.dart';

class VisitRepositoryImpl implements VisitRepository {
  const VisitRepositoryImpl(this._remote);

  final VisitRemoteDataSource _remote;

  @override
  Future<Result<List<Host>>> getHosts() => guard(_remote.hosts);

  @override
  Future<Result<List<VisitorProfile>>> searchVisitors(String query) => guard(() => _remote.searchVisitors(query));

  @override
  Future<Result<BlacklistEntry?>> checkBlacklist({String? phone, String? idNumber}) =>
      guard(() => _remote.checkBlacklist(phone, idNumber));

  @override
  Future<Result<Paged<Visit>>> getVisits(VisitQuery query) => guard(() => _remote.visits(query));

  @override
  Future<Result<Visit>> getVisit(int id) => guard(() => _remote.visit(id));

  @override
  Future<Result<Visit>> lookup(String code) => guard(() => _remote.lookup(code));

  @override
  Future<Result<Visit>> checkInWalkIn(WalkInCheckin request) => guard(() => _remote.checkInWalkIn(request));

  @override
  Future<Result<Visit>> checkInExisting(ExistingCheckin request) => guard(() => _remote.checkInExisting(request));

  @override
  Future<Result<Visit>> preregister(VisitForm form) => guard(() => _remote.preregister(form));

  @override
  Future<Result<Visit>> update(int id, VisitForm form) => guard(() => _remote.update(id, form));

  @override
  Future<Result<Visit>> decide(int id, VisitDecision decision, {String? remarks}) =>
      guard(() => _remote.decide(id, decision, remarks));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));

  @override
  Future<Result<List<Visit>>> activeVisits() => guard(_remote.active);

  @override
  Future<Result<Visit>> checkoutByCode(String code) => guard(() => _remote.checkoutByCode(code));

  @override
  Future<Result<Map<VisitStatus, int>>> statusCounts(VisitQuery query) => guard(() => _remote.statusCounts(query));
}
