import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/json_utils.dart';
import '../domain/blacklist_repository.dart';

class BlacklistRemoteDataSource {
  const BlacklistRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<BlacklistItem>> all() async {
    final rows = await _api.get('blacklist') as List;
    return [for (final r in rows.cast<Map<String, dynamic>>()) _item(r)];
  }

  Future<BlacklistItem> create(BlacklistInput input) async =>
      _item(await _api.post('blacklist', data: _json(input)) as Map<String, dynamic>);

  Future<BlacklistItem> update(int id, BlacklistInput input) async =>
      _item(await _api.put('blacklist/$id', data: _json(input)) as Map<String, dynamic>);

  Future<void> delete(int id) => _api.delete('blacklist/$id');

  static Map<String, dynamic> _json(BlacklistInput i) => {
    'name': i.name ?? '',
    'phone': i.phone ?? '',
    'id_number': i.idNumber ?? '',
    'reason': i.reason,
  };

  static BlacklistItem _item(Map<String, dynamic> r) => BlacklistItem(
    id: parseInt(r['id'])!,
    name: parseString(r['name']),
    phone: parseString(r['phone']),
    idNumber: parseString(r['id_number']),
    reason: r['reason']?.toString() ?? '',
    addedByName: parseString(r['added_by_name']),
    createdAt: parseDateTime(r['created_at']),
  );
}

class BlacklistRepositoryImpl implements BlacklistRepository {
  const BlacklistRepositoryImpl(this._remote);

  final BlacklistRemoteDataSource _remote;

  @override
  Future<Result<List<BlacklistItem>>> getAll() => guard(_remote.all);

  @override
  Future<Result<BlacklistItem>> create(BlacklistInput input) => guard(() => _remote.create(input));

  @override
  Future<Result<BlacklistItem>> update(int id, BlacklistInput input) => guard(() => _remote.update(id, input));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));
}
