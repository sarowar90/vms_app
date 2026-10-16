import '../../domain/entities/user.dart';

/// JSON mapping for [User]. PHP/PDO may send numbers as strings,
/// so ids are parsed defensively.
class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.username,
    required super.role,
    required super.roleName,
    required super.permissions,
    required super.isSuperAdmin,
    super.email,
    super.employeeId,
    super.branchId,
    super.company,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    final permissions = json['permissions'];
    return UserModel(
      id: _int(json['id'])!,
      name: json['name']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString(),
      role: json['role']?.toString() ?? '',
      roleName: json['role_name']?.toString() ?? '',
      permissions: permissions is List ? permissions.map((e) => e.toString()).toList() : const [],
      isSuperAdmin: json['is_super_admin'] == true,
      employeeId: _int(json['employee_id']),
      branchId: _int(json['branch_id']),
      company: company is Map<String, dynamic>
          ? Company(
              id: _int(company['id'])!,
              name: company['name']?.toString() ?? '',
              nameBn: company['name_bn']?.toString(),
              code: company['code']?.toString() ?? '',
            )
          : null,
    );
  }

  static int? _int(Object? value) => value == null ? null : int.tryParse(value.toString());
}
