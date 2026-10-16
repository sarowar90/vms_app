import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../entities/visit_entities.dart';

abstract interface class VisitRepository {
  Future<Result<List<Host>>> getHosts();

  Future<Result<List<VisitorProfile>>> searchVisitors(String query);

  /// The blacklist entry matching the phone or ID number, or `null`.
  Future<Result<BlacklistEntry?>> checkBlacklist({String? phone, String? idNumber});

  Future<Result<Paged<Visit>>> getVisits(VisitQuery query);

  Future<Result<Visit>> getVisit(int id);

  /// Find a visit by visit code (QR), visit no or RFID card no.
  Future<Result<Visit>> lookup(String code);

  Future<Result<Visit>> checkInWalkIn(WalkInCheckin request);

  Future<Result<Visit>> checkInExisting(ExistingCheckin request);

  Future<Result<Visit>> preregister(VisitForm form);

  Future<Result<Visit>> update(int id, VisitForm form);

  Future<Result<Visit>> decide(int id, VisitDecision decision, {String? remarks});

  Future<Result<void>> delete(int id);

  /// Visitors currently inside (status checked_in), newest entry first.
  Future<Result<List<Visit>>> activeVisits();

  /// Check out by visit code (QR), visit no or RFID card no.
  Future<Result<Visit>> checkoutByCode(String code);

  /// Visit count per status for the same filters (needs `reports.view`).
  Future<Result<Map<VisitStatus, int>>> statusCounts(VisitQuery query);
}
