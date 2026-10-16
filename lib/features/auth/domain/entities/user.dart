/// The logged-in user. Pure Dart: no JSON, no Flutter.
class User {
  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    required this.roleName,
    required this.permissions,
    required this.isSuperAdmin,
    this.email,
    this.employeeId,
    this.branchId,
    this.company,
  });

  final int id;
  final String name;
  final String username;
  final String? email;

  /// Role slug, e.g. `admin`, `receptionist`, `employee`.
  final String role;
  final String roleName;
  final List<String> permissions;
  final bool isSuperAdmin;
  final int? employeeId;
  final int? branchId;
  final Company? company;

  bool can(String permission) => role == 'admin' || permissions.contains(permission);

  /// True when [required] is empty or the user has any of them.
  bool canAny(List<String> required) => required.isEmpty || required.any(can);
}

class Company {
  const Company({required this.id, required this.name, required this.code, this.nameBn});

  final int id;
  final String name;
  final String? nameBn;
  final String code;
}
