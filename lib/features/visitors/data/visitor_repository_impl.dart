import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/json_utils.dart';
import '../../../shared/data/models/visit_model.dart';
import '../../../shared/domain/entities/paged.dart';
import '../../visits/data/datasources/visit_remote_data_source.dart';
import '../../visits/domain/entities/visit_entities.dart';
import '../domain/visitor_repository.dart';

class VisitorRemoteDataSource {
  const VisitorRemoteDataSource(this._api);

  final ApiClient _api;

  Future<Paged<VisitorProfile>> list(String? q, int page) async {
    final (rows, meta) = await _api.getPaged(
      'visitors',
      query: {if (q != null && q.trim().isNotEmpty) 'q': q.trim(), 'page': page, 'per_page': 25},
    );
    return Paged(
      items: [for (final r in rows) visitorProfileFromJson(r as Map<String, dynamic>)],
      total: parseInt(meta['total']) ?? rows.length,
      page: parseInt(meta['page']) ?? page,
      lastPage: parseInt(meta['last_page']) ?? page,
    );
  }

  Future<VisitorDetail> show(int id) async {
    final d = await _api.get('visitors/$id') as Map<String, dynamic>;
    final visitor = visitorProfileFromJson(d);
    return VisitorDetail(
      visitor: visitor,
      visits: [
        // History rows carry visit fields only; add the visitor's name for display.
        for (final v in (d['visits'] as List? ?? const []).cast<Map<String, dynamic>>())
          VisitModel.fromJson({...v, 'visitor_name': visitor.name}),
      ],
    );
  }

  Future<VisitorProfile> update(int id, VisitorInput input, String? photo) async {
    final d = await _api.put('visitors/$id', data: {...visitorInputJson(input), 'photo': ?photo});
    return visitorProfileFromJson(d as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('visitors/$id');
}

class VisitorRepositoryImpl implements VisitorRepository {
  const VisitorRepositoryImpl(this._remote);

  final VisitorRemoteDataSource _remote;

  @override
  Future<Result<Paged<VisitorProfile>>> getVisitors({String? q, int page = 1}) => guard(() => _remote.list(q, page));

  @override
  Future<Result<VisitorDetail>> getVisitor(int id) => guard(() => _remote.show(id));

  @override
  Future<Result<VisitorProfile>> update(int id, VisitorInput input, {String? photoDataUri}) =>
      guard(() => _remote.update(id, input, photoDataUri));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));
}
