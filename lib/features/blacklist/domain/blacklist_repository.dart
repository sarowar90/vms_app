import '../../../core/error/failures.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';

/// A blocked mobile and/or ID number. Blocked at check-in and pre-registration.
class BlacklistItem {
  const BlacklistItem({
    required this.id,
    required this.reason,
    this.name,
    this.phone,
    this.idNumber,
    this.addedByName,
    this.createdAt,
  });

  final int id;
  final String? name;
  final String? phone;
  final String? idNumber;
  final String reason;
  final String? addedByName;
  final DateTime? createdAt;
}

class BlacklistInput {
  const BlacklistInput({required this.reason, this.name, this.phone, this.idNumber});

  final String? name;
  final String? phone;
  final String? idNumber;
  final String reason;
}

abstract interface class BlacklistRepository {
  Future<Result<List<BlacklistItem>>> getAll();

  Future<Result<BlacklistItem>> create(BlacklistInput input);

  Future<Result<BlacklistItem>> update(int id, BlacklistInput input);

  Future<Result<void>> delete(int id);
}

// ---------- Use cases ----------

class GetBlacklist implements UseCase<List<BlacklistItem>, NoParams> {
  const GetBlacklist(this._repo);

  final BlacklistRepository _repo;

  @override
  Future<Result<List<BlacklistItem>>> call(NoParams params) => _repo.getAll();
}

/// Add (when [id] is null) or edit an entry. A mobile or ID number is required,
/// same as the server.
class SaveBlacklistEntry implements UseCase<BlacklistItem, ({int? id, BlacklistInput input})> {
  const SaveBlacklistEntry(this._repo);

  final BlacklistRepository _repo;

  @override
  Future<Result<BlacklistItem>> call(({int? id, BlacklistInput input}) p) async {
    if ((p.input.phone ?? '').isEmpty && (p.input.idNumber ?? '').isEmpty) {
      return const Error(
        ServerFailure(
          'Validation failed',
          statusCode: 422,
          errors: {
            'phone': ['Mobile number or ID number is required'],
          },
        ),
      );
    }
    return p.id == null ? _repo.create(p.input) : _repo.update(p.id!, p.input);
  }
}

class DeleteBlacklistEntry implements UseCase<void, int> {
  const DeleteBlacklistEntry(this._repo);

  final BlacklistRepository _repo;

  @override
  Future<Result<void>> call(int id) => _repo.delete(id);
}
