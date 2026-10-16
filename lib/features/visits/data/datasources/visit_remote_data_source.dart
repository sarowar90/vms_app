import 'package:intl/intl.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/data/json_utils.dart';
import '../../../../shared/data/models/visit_model.dart';
import '../../../../shared/domain/entities/paged.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../domain/entities/visit_entities.dart';

final _day = DateFormat('yyyy-MM-dd');
final _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss');

/// A row of the `visitors` table (search, list and profile endpoints).
VisitorProfile visitorProfileFromJson(Map<String, dynamic> v) => VisitorProfile(
  id: parseInt(v['id'])!,
  name: v['name']?.toString() ?? '',
  phone: v['phone']?.toString() ?? '',
  email: parseString(v['email']),
  company: parseString(v['company']),
  designation: parseString(v['designation']),
  address: parseString(v['address']),
  idType: IdType.fromValue(parseString(v['id_type'])),
  idNumber: parseString(v['id_number']),
  gender: Gender.fromValue(parseString(v['gender'])),
  photoUrl: AppConfig.resolveUrl(parseString(v['photo_url'])),
  blacklisted: v['blacklisted'] == true,
  visitsCount: parseInt(v['visits_count']),
  lastVisit: parseDateTime(v['last_visit']),
  createdAt: parseDateTime(v['created_at']),
);

/// The visitor fields the API accepts on create/update.
Map<String, dynamic> visitorInputJson(VisitorInput v) => {
  'phone': v.phone,
  'name': v.name,
  'email': v.email ?? '',
  'company': v.company ?? '',
  'designation': v.designation ?? '',
  'address': v.address ?? '',
  'id_type': v.idType?.value ?? '',
  'id_number': v.idNumber ?? '',
  'gender': v.gender?.value ?? '',
};

class VisitRemoteDataSource {
  const VisitRemoteDataSource(this._api);

  final ApiClient _api;

  Future<List<Host>> hosts() async {
    final rows = await _api.get('employees', query: {'status': 1}) as List;
    return [
      for (final e in rows.cast<Map<String, dynamic>>())
        Host(
          id: parseInt(e['id'])!,
          name: e['name']?.toString() ?? '',
          designation: parseString(e['designation']),
          departmentName: parseString(e['department_name']),
        ),
    ];
  }

  Future<List<VisitorProfile>> searchVisitors(String q) async {
    final rows = await _api.get('visitors/search', query: {'q': q}) as List;
    return [for (final v in rows.cast<Map<String, dynamic>>()) visitorProfileFromJson(v)];
  }

  Future<BlacklistEntry?> checkBlacklist(String? phone, String? idNumber) async {
    final d =
        await _api.get('blacklist/check', query: {'phone': ?phone, 'id_number': ?idNumber}) as Map<String, dynamic>;
    final entry = d['entry'];
    return entry is Map<String, dynamic>
        ? BlacklistEntry(name: entry['name']?.toString() ?? '', reason: parseString(entry['reason']))
        : null;
  }

  Map<String, dynamic> _filters(VisitQuery q) => {
    if (q.statuses.isNotEmpty) 'status': q.statuses.map((s) => s.value).join(','),
    if (q.q != null && q.q!.trim().isNotEmpty) 'q': q.q!.trim(),
    'visit_type': ?q.visitType?.value,
    if (q.from != null) 'from': _day.format(q.from!),
    if (q.to != null) 'to': _day.format(q.to!),
  };

  Future<Paged<Visit>> visits(VisitQuery q) async {
    final (rows, meta) = await _api.getPaged('visits', query: {..._filters(q), 'page': q.page, 'per_page': q.perPage});
    return Paged(
      items: [for (final r in rows) VisitModel.fromJson(r as Map<String, dynamic>)],
      total: parseInt(meta['total']) ?? rows.length,
      page: parseInt(meta['page']) ?? q.page,
      lastPage: parseInt(meta['last_page']) ?? q.page,
    );
  }

  Future<Visit> visit(int id) async => VisitModel.fromJson(await _api.get('visits/$id') as Map<String, dynamic>);

  Future<Visit> lookup(String code) async =>
      VisitModel.fromJson(await _api.get('visits/lookup', query: {'q': code}) as Map<String, dynamic>);

  Future<Visit> checkInWalkIn(WalkInCheckin r) => _visit(
    _api.post(
      'visits/checkin',
      data: {
        ..._visitorJson(r.visitor),
        ..._detailsJson(r.details),
        'checkin_method': r.method.value,
        'hold_for_approval': r.holdForApproval ? 1 : 0,
        'photo': ?r.photoDataUri,
      },
    ),
  );

  Future<Visit> checkInExisting(ExistingCheckin r) => _visit(
    _api.post(
      'visits/checkin',
      data: {
        'visit_id': r.visitId,
        'checkin_method': r.method.value,
        'card_no': r.cardNo ?? '',
        'persons_count': ?r.personsCount,
        'carrying_goods': r.carryingGoods ?? '',
        'vehicle_no': r.vehicleNo ?? '',
        'remarks': r.remarks ?? '',
      },
    ),
  );

  Future<Visit> preregister(VisitForm f) => _visit(_api.post('visits', data: _formJson(f)));

  Future<Visit> update(int id, VisitForm f) => _visit(_api.put('visits/$id', data: _formJson(f)));

  Future<Visit> decide(int id, VisitDecision d, String? remarks) =>
      _visit(_api.post('visits/$id/${d.name}', data: {'remarks': remarks ?? ''}));

  Future<void> delete(int id) => _api.delete('visits/$id');

  Future<List<Visit>> active() async {
    final rows = await _api.get('visits/active') as List;
    return [for (final r in rows) VisitModel.fromJson(r as Map<String, dynamic>)];
  }

  Future<Visit> checkoutByCode(String code) => _visit(_api.post('visits/checkout', data: {'code': code}));

  Future<Map<VisitStatus, int>> statusCounts(VisitQuery q) async {
    final d =
        await _api.get(
              'reports/summary',
              query: {
                ..._filters(q.copyWith(statuses: const [])),
                'group_by': 'status',
              },
            )
            as Map<String, dynamic>;
    return {
      for (final r in (d['rows'] as List? ?? const []).cast<Map<String, dynamic>>())
        VisitStatus.fromValue(parseString(r['label'])): parseInt(r['visits']) ?? 0,
    };
  }

  Future<Visit> _visit(Future<dynamic> request) async => VisitModel.fromJson(await request as Map<String, dynamic>);

  Map<String, dynamic> _formJson(VisitForm f) => {
    ..._visitorJson(f.visitor),
    ..._detailsJson(f.details),
    'scheduled_at': _dateTime.format(f.scheduledAt),
  };

  Map<String, dynamic> _visitorJson(VisitorInput v) => visitorInputJson(v);

  Map<String, dynamic> _detailsJson(VisitDetails d) => {
    'host_employee_id': ?d.hostEmployeeId,
    'visit_type': d.visitType.value,
    'purpose': d.purpose ?? '',
    'persons_count': d.personsCount,
    'carrying_goods': d.carryingGoods ?? '',
    'vehicle_no': d.vehicleNo ?? '',
    'card_no': d.cardNo ?? '',
    'remarks': d.remarks ?? '',
  };
}
