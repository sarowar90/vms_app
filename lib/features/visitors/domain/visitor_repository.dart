import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import '../../../shared/domain/entities/paged.dart';
import '../../../shared/domain/entities/visit.dart';
import '../../visits/domain/entities/visit_entities.dart';

/// A visitor with their visit history (newest first, up to 100).
class VisitorDetail {
  const VisitorDetail({required this.visitor, required this.visits});

  final VisitorProfile visitor;
  final List<Visit> visits;

  /// Visits with both an entry and an exit time.
  List<Visit> get completed =>
      visits.where((v) => v.status == VisitStatus.checkedOut && v.checkInAt != null && v.checkOutAt != null).toList();

  DateTime? get lastVisit {
    final times = visits.map((v) => v.checkInAt).whereType<DateTime>().toList()..sort();
    return times.lastOrNull;
  }

  int? get averageMinutes {
    final done = completed;
    if (done.isEmpty) return null;
    final total = done.fold<int>(0, (sum, v) => sum + v.checkOutAt!.difference(v.checkInAt!).inMinutes);
    return (total / done.length).round();
  }
}

abstract interface class VisitorRepository {
  Future<Result<Paged<VisitorProfile>>> getVisitors({String? q, int page = 1});

  Future<Result<VisitorDetail>> getVisitor(int id);

  /// [photoDataUri] replaces the photo when given (`data:image/jpeg;base64,...`).
  Future<Result<VisitorProfile>> update(int id, VisitorInput input, {String? photoDataUri});

  /// The server only allows this when the visitor has no visits.
  Future<Result<void>> delete(int id);
}

// ---------- Use cases ----------

class GetVisitors implements UseCase<Paged<VisitorProfile>, ({String? q, int page})> {
  const GetVisitors(this._repo);

  final VisitorRepository _repo;

  @override
  Future<Result<Paged<VisitorProfile>>> call(({String? q, int page}) p) => _repo.getVisitors(q: p.q, page: p.page);
}

class GetVisitorDetail implements UseCase<VisitorDetail, int> {
  const GetVisitorDetail(this._repo);

  final VisitorRepository _repo;

  @override
  Future<Result<VisitorDetail>> call(int id) => _repo.getVisitor(id);
}

class UpdateVisitor implements UseCase<VisitorProfile, ({int id, VisitorInput input, String? photo})> {
  const UpdateVisitor(this._repo);

  final VisitorRepository _repo;

  @override
  Future<Result<VisitorProfile>> call(({int id, VisitorInput input, String? photo}) p) =>
      _repo.update(p.id, p.input, photoDataUri: p.photo);
}

class DeleteVisitor implements UseCase<void, int> {
  const DeleteVisitor(this._repo);

  final VisitorRepository _repo;

  @override
  Future<Result<void>> call(int id) => _repo.delete(id);
}
