/// Setup ("master") records. `id == null` means a new record not saved yet.
sealed class MasterItem {
  const MasterItem({this.id, required this.name, this.active = true});

  final int? id;
  final String name;
  final bool active;

  /// Text the list search matches against (web: all visible columns).
  String get searchText;
}

class Branch extends MasterItem {
  const Branch({
    super.id,
    required super.name,
    super.active,
    this.address,
    this.phone,
    this.departmentsCount = 0,
    this.employeesCount = 0,
  });

  final String? address;
  final String? phone;
  final int departmentsCount;
  final int employeesCount;

  @override
  String get searchText => [name, address, phone].whereType<String>().join(' ');
}

class Department extends MasterItem {
  const Department({
    super.id,
    required super.name,
    super.active,
    this.branchId,
    this.branchName,
    this.employeesCount = 0,
  });

  final int? branchId;
  final String? branchName;
  final int employeesCount;

  @override
  String get searchText => [name, branchName].whereType<String>().join(' ');
}

/// A login of this company (web: Users page). Not the logged-in [User] entity.
class AppUser extends MasterItem {
  const AppUser({
    super.id,
    required super.name,
    super.active,
    required this.username,
    required this.roleId,
    this.email,
    this.password,
    this.roleName,
    this.roleIsSystem = false,
    this.employeeId,
    this.employeeName,
    this.branchId,
    this.branchName,
    this.lastLogin,
  });

  final String username;
  final String? email;

  /// Only sent when creating, or when changing it on edit (blank keeps the current one).
  final String? password;
  final int roleId;
  final String? roleName;

  /// The built-in Admin role.
  final bool roleIsSystem;
  final int? employeeId;
  final String? employeeName;
  final int? branchId;
  final String? branchName;
  final DateTime? lastLogin;

  @override
  String get searchText => [name, username, email, roleName, employeeName, branchName].whereType<String>().join(' ');
}

/// A named set of permissions (web: Roles & Permissions).
class Role extends MasterItem {
  const Role({
    super.id,
    required super.name,
    this.nameBn,
    this.slug,
    this.description,
    this.permissions = const [],
    this.isSystem = false,
    this.allAccess = false,
    this.usersCount = 0,
  });

  final String? nameBn;

  /// e.g. `admin`, `receptionist`, `employee`.
  final String? slug;
  final String? description;
  final List<String> permissions;

  /// The built-in Admin role: every permission, cannot be changed or deleted.
  final bool isSystem;
  final bool allAccess;
  final int usersCount;

  /// Roles without "See all visits" only see visits where the user is the host,
  /// so their users must be linked to an employee.
  bool get needsEmployee => !permissions.contains('visits.view_all');

  @override
  String get searchText => [name, nameBn, description].whereType<String>().join(' ');
}

class Employee extends MasterItem {
  const Employee({
    super.id,
    required super.name,
    super.active,
    required this.code,
    this.designation,
    this.departmentId,
    this.departmentName,
    this.branchId,
    this.branchName,
    this.phone,
    this.email,
  });

  /// Employee code, e.g. `EMP-004`.
  final String code;
  final String? designation;
  final int? departmentId;
  final String? departmentName;
  final int? branchId;
  final String? branchName;
  final String? phone;
  final String? email;

  @override
  String get searchText =>
      [code, name, designation, departmentName, branchName, phone, email].whereType<String>().join(' ');
}
