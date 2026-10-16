import '../../../core/network/api_client.dart';
import '../../../core/utils/guard.dart';
import '../../../core/utils/result.dart';
import '../../../shared/data/json_utils.dart';
import '../domain/master_entities.dart';
import '../domain/master_repository.dart';

/// REST resource with index/store/update/destroy, plus its JSON mapping.
class MasterRemoteDataSource<T extends MasterItem> {
  const MasterRemoteDataSource(this._api, {required this.endpoint, required this.fromJson, required this.toJson});

  final ApiClient _api;
  final String endpoint;
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;

  Future<List<T>> all() async {
    final rows = await _api.get(endpoint) as List;
    return [for (final r in rows.cast<Map<String, dynamic>>()) fromJson(r)];
  }

  Future<T> save(T item) async {
    final body = toJson(item);
    final data = item.id == null
        ? await _api.post(endpoint, data: body)
        : await _api.put('$endpoint/${item.id}', data: body);
    return fromJson(data as Map<String, dynamic>);
  }

  Future<void> delete(int id) => _api.delete('$endpoint/$id');
}

class MasterRepositoryImpl<T extends MasterItem> implements MasterRepository<T> {
  const MasterRepositoryImpl(this._remote);

  final MasterRemoteDataSource<T> _remote;

  @override
  Future<Result<List<T>>> getAll() => guard(_remote.all);

  @override
  Future<Result<T>> save(T item) => guard(() => _remote.save(item));

  @override
  Future<Result<void>> delete(int id) => guard(() => _remote.delete(id));
}

// ---------- JSON mapping (`external_api/controllers/*Controller.php`) ----------

bool _active(Object? v) => parseInt(v) != 0;

Branch branchFromJson(Map<String, dynamic> j) => Branch(
  id: parseInt(j['id']),
  name: j['name']?.toString() ?? '',
  address: parseString(j['address']),
  phone: parseString(j['phone']),
  active: _active(j['status']),
  departmentsCount: parseInt(j['departments_count']) ?? 0,
  employeesCount: parseInt(j['employees_count']) ?? 0,
);

Map<String, dynamic> branchToJson(Branch b) => {
  'name': b.name,
  'address': b.address ?? '',
  'phone': b.phone ?? '',
  'status': b.active ? 1 : 0,
};

Department departmentFromJson(Map<String, dynamic> j) => Department(
  id: parseInt(j['id']),
  name: j['name']?.toString() ?? '',
  branchId: parseInt(j['branch_id']),
  branchName: parseString(j['branch_name']),
  active: _active(j['status']),
  employeesCount: parseInt(j['employees_count']) ?? 0,
);

Map<String, dynamic> departmentToJson(Department d) => {
  'name': d.name,
  'branch_id': d.branchId ?? '',
  'status': d.active ? 1 : 0,
};

AppUser userFromJson(Map<String, dynamic> j) => AppUser(
  id: parseInt(j['id']),
  name: j['name']?.toString() ?? '',
  username: j['username']?.toString() ?? '',
  email: parseString(j['email']),
  roleId: parseInt(j['role_id']) ?? 0,
  roleName: parseString(j['role_name']),
  roleIsSystem: parseInt(j['role_is_system']) == 1,
  employeeId: parseInt(j['employee_id']),
  employeeName: parseString(j['employee_name']),
  branchId: parseInt(j['branch_id']),
  branchName: parseString(j['branch_name']),
  lastLogin: parseDateTime(j['last_login']),
  active: _active(j['status']),
);

Map<String, dynamic> userToJson(AppUser u) => {
  'name': u.name,
  'username': u.username,
  'email': u.email ?? '',
  if ((u.password ?? '').isNotEmpty) 'password': u.password,
  'role_id': u.roleId,
  'employee_id': u.employeeId ?? '',
  'branch_id': u.branchId ?? '',
  'status': u.active ? 1 : 0,
};

Role roleFromJson(Map<String, dynamic> j) => Role(
  id: parseInt(j['id']),
  name: j['name']?.toString() ?? '',
  nameBn: parseString(j['name_bn']),
  slug: parseString(j['slug']),
  description: parseString(j['description']),
  permissions: [for (final p in (j['permissions'] as List? ?? const [])) p.toString()],
  isSystem: parseInt(j['is_system']) == 1,
  allAccess: j['all_access'] == true,
  usersCount: parseInt(j['users_count']) ?? 0,
);

Map<String, dynamic> roleToJson(Role r) => {
  'name': r.name,
  'name_bn': r.nameBn ?? '',
  'description': r.description ?? '',
  'permissions': r.permissions,
};

/// Permission catalog for the matrix: group => permission keys (`GET roles/permissions`).
Future<List<(String, List<String>)>> fetchPermissionCatalog(ApiClient api) async {
  final rows = await api.get('roles/permissions') as List;
  return [
    for (final g in rows.cast<Map<String, dynamic>>())
      (g['group'] as String, [for (final p in g['permissions'] as List) p.toString()]),
  ];
}

Employee employeeFromJson(Map<String, dynamic> j) => Employee(
  id: parseInt(j['id']),
  code: j['employee_code']?.toString() ?? '',
  name: j['name']?.toString() ?? '',
  designation: parseString(j['designation']),
  departmentId: parseInt(j['department_id']),
  departmentName: parseString(j['department_name']),
  branchId: parseInt(j['branch_id']),
  branchName: parseString(j['branch_name']),
  phone: parseString(j['phone']),
  email: parseString(j['email']),
  active: _active(j['status']),
);

Map<String, dynamic> employeeToJson(Employee e) => {
  'employee_code': e.code,
  'name': e.name,
  'designation': e.designation ?? '',
  'department_id': e.departmentId ?? '',
  'branch_id': e.branchId ?? '',
  'phone': e.phone ?? '',
  'email': e.email ?? '',
  'status': e.active ? 1 : 0,
};
