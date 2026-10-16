import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import 'master_entities.dart';

/// List / add / edit / delete of one setup table (web: `crud.js`).
abstract interface class MasterRepository<T extends MasterItem> {
  Future<Result<List<T>>> getAll();

  /// Creates [item] when its id is null, otherwise updates it.
  Future<Result<T>> save(T item);

  Future<Result<void>> delete(int id);
}

class GetMasters<T extends MasterItem> implements UseCase<List<T>, NoParams> {
  const GetMasters(this._repo);

  final MasterRepository<T> _repo;

  @override
  Future<Result<List<T>>> call(NoParams params) => _repo.getAll();
}

class SaveMaster<T extends MasterItem> implements UseCase<T, T> {
  const SaveMaster(this._repo);

  final MasterRepository<T> _repo;

  @override
  Future<Result<T>> call(T item) => _repo.save(item);
}

class DeleteMaster<T extends MasterItem> implements UseCase<void, int> {
  const DeleteMaster(this._repo);

  final MasterRepository<T> _repo;

  @override
  Future<Result<void>> call(int id) => _repo.delete(id);
}
