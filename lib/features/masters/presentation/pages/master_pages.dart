import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/validators.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../domain/master_entities.dart';
import '../master_providers.dart';
import '../widgets/master_list_page.dart';

String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

InputDecoration _decoration(String label, String? error, {String? hint}) =>
    InputDecoration(labelText: label, hintText: hint, errorText: error, border: const OutlineInputBorder());

// =====================================================================
// Branches (web: branches.php)
// =====================================================================

class BranchesPage extends StatelessWidget {
  const BranchesPage({super.key});

  @override
  Widget build(BuildContext context) => MasterListPage<Branch>(
    title: 'Branches',
    list: branchesProvider,
    mutation: branchMutationProvider.notifier,
    tile: (b) => (
      icon: Icons.business,
      title: b.name,
      code: null,
      lines: [
        if (b.address != null || b.phone != null) [?b.address, ?b.phone].join(' · '),
        '${b.departmentsCount} departments · ${b.employeesCount} employees',
      ],
    ),
    form: (b) => _BranchForm(item: b),
  );
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({this.item});

  final Branch? item;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _address = TextEditingController(text: widget.item?.address);
  late final _phone = TextEditingController(text: widget.item?.phone);
  late bool _active = widget.item?.active ?? true;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await ref
        .read(branchMutationProvider.notifier)
        .save(
          Branch(
            id: widget.item?.id,
            name: _name.text.trim(),
            address: _opt(_address),
            phone: _opt(_phone),
            active: _active,
          ),
        );
    if (saved != null && mounted) {
      Navigator.of(context).pop(widget.item == null ? 'Saved successfully' : 'Updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(branchMutationProvider);
    final err = state.error;
    return MasterFormSheet(
      formKey: _formKey,
      title: widget.item == null ? 'Add Branch' : 'Edit Branch',
      saving: state.isLoading,
      failure: err,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          maxLength: 150,
          decoration: _decoration('Name *', masterFieldError(err, 'name')),
          validator: (v) => Validators.required(v, 'Name'),
        ),
        TextFormField(controller: _address, decoration: _decoration('Address', masterFieldError(err, 'address'))),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          maxLength: 20,
          decoration: _decoration('Phone', masterFieldError(err, 'phone')),
        ),
        ActiveSwitch(value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
    );
  }
}

// =====================================================================
// Departments (web: departments.php)
// =====================================================================

class DepartmentsPage extends StatelessWidget {
  const DepartmentsPage({super.key});

  @override
  Widget build(BuildContext context) => MasterListPage<Department>(
    title: 'Departments',
    list: departmentsProvider,
    mutation: departmentMutationProvider.notifier,
    tile: (d) => (
      icon: Icons.account_tree_outlined,
      title: d.name,
      code: null,
      lines: [
        [d.branchName ?? 'No branch', '${d.employeesCount} employees'].join(' · '),
      ],
    ),
    form: (d) => _DepartmentForm(item: d),
  );
}

class _DepartmentForm extends ConsumerStatefulWidget {
  const _DepartmentForm({this.item});

  final Department? item;

  @override
  ConsumerState<_DepartmentForm> createState() => _DepartmentFormState();
}

class _DepartmentFormState extends ConsumerState<_DepartmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  // New departments default to branch #1 (Head Office), like the web.
  late int? _branchId = widget.item == null ? 1 : widget.item!.branchId;
  late bool _active = widget.item?.active ?? true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await ref
        .read(departmentMutationProvider.notifier)
        .save(Department(id: widget.item?.id, name: _name.text.trim(), branchId: _branchId, active: _active));
    if (saved != null && mounted) {
      Navigator.of(context).pop(widget.item == null ? 'Saved successfully' : 'Updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(departmentMutationProvider);
    final err = state.error;
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];
    return MasterFormSheet(
      formKey: _formKey,
      title: widget.item == null ? 'Add Department' : 'Edit Department',
      saving: state.isLoading,
      failure: err,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          maxLength: 150,
          decoration: _decoration('Name *', masterFieldError(err, 'name')),
          validator: (v) => Validators.required(v, 'Name'),
        ),
        _IdDropdown(
          label: 'Branch',
          value: _branchId,
          error: masterFieldError(err, 'branch_id'),
          options: [for (final b in branches) (b.id!, b.name)],
          onChanged: (v) => _branchId = v,
        ),
        ActiveSwitch(value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
    );
  }
}

// =====================================================================
// Employees / Hosts (web: employees.php)
// =====================================================================

class EmployeesPage extends StatelessWidget {
  const EmployeesPage({super.key});

  @override
  Widget build(BuildContext context) => MasterListPage<Employee>(
    title: 'Employees / Hosts',
    list: employeesProvider,
    mutation: employeeMutationProvider.notifier,
    tile: (e) => (
      icon: Icons.badge_outlined,
      title: e.name,
      code: e.code,
      lines: [
        [?e.designation, ?e.departmentName, ?e.branchName].join(' · '),
        if (e.phone != null || e.email != null) [?e.phone, ?e.email].join(' · '),
      ].where((l) => l.isNotEmpty).toList(),
    ),
    form: (e) => _EmployeeForm(item: e),
  );
}

class _EmployeeForm extends ConsumerStatefulWidget {
  const _EmployeeForm({this.item});

  final Employee? item;

  @override
  ConsumerState<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends ConsumerState<_EmployeeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.item?.code);
  late final _name = TextEditingController(text: widget.item?.name);
  late final _designation = TextEditingController(text: widget.item?.designation);
  late final _phone = TextEditingController(text: widget.item?.phone);
  late final _email = TextEditingController(text: widget.item?.email);
  late int? _departmentId = widget.item?.departmentId;
  late int? _branchId = widget.item == null ? 1 : widget.item!.branchId;
  late bool _active = widget.item?.active ?? true;

  @override
  void dispose() {
    for (final c in [_code, _name, _designation, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await ref
        .read(employeeMutationProvider.notifier)
        .save(
          Employee(
            id: widget.item?.id,
            code: _code.text.trim(),
            name: _name.text.trim(),
            designation: _opt(_designation),
            departmentId: _departmentId,
            branchId: _branchId,
            phone: _opt(_phone),
            email: _opt(_email),
            active: _active,
          ),
        );
    if (saved != null && mounted) {
      Navigator.of(context).pop(widget.item == null ? 'Saved successfully' : 'Updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(employeeMutationProvider);
    final err = state.error;
    final departments = ref.watch(departmentsProvider).value ?? const <Department>[];
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];

    return MasterFormSheet(
      formKey: _formKey,
      title: widget.item == null ? 'Add Employee' : 'Edit Employee',
      saving: state.isLoading,
      failure: err,
      onSave: _save,
      children: [
        TextFormField(
          controller: _code,
          maxLength: 50,
          decoration: _decoration('Employee Code *', masterFieldError(err, 'employee_code'), hint: 'EMP-001'),
          validator: (v) => Validators.required(v, 'Employee code'),
        ),
        TextFormField(
          controller: _name,
          maxLength: 150,
          decoration: _decoration('Name *', masterFieldError(err, 'name')),
          validator: (v) => Validators.required(v, 'Name'),
        ),
        TextFormField(
          controller: _designation,
          decoration: _decoration('Designation', masterFieldError(err, 'designation')),
        ),
        _IdDropdown(
          label: 'Department',
          value: _departmentId,
          error: masterFieldError(err, 'department_id'),
          options: [
            for (final d in departments) (d.id!, d.branchName == null ? d.name : '${d.name} (${d.branchName})'),
          ],
          // Picking a department also picks its branch, like the web.
          onChanged: (v) => setState(() {
            _departmentId = v;
            final branch = departments.where((d) => d.id == v).firstOrNull?.branchId;
            if (branch != null) _branchId = branch;
          }),
        ),
        _IdDropdown(
          label: 'Branch',
          value: _branchId,
          error: masterFieldError(err, 'branch_id'),
          options: [for (final b in branches) (b.id!, b.name)],
          onChanged: (v) => setState(() => _branchId = v),
        ),
        TextFormField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: _decoration('Mobile', masterFieldError(err, 'phone'), hint: '01XXXXXXXXX'),
          validator: (v) => v == null || v.trim().isEmpty ? null : Validators.bdPhone(v),
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _decoration('Email', masterFieldError(err, 'email')),
          validator: Validators.email,
        ),
        ActiveSwitch(value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
    );
  }
}

/// Dropdown of (id, label) options with a "Select" (null) choice.
class _IdDropdown extends StatelessWidget {
  const _IdDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.error,
  });

  final String label;
  final int? value;
  final List<(int, String)> options;
  final ValueChanged<int?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final known = options.any((o) => o.$1 == value);
    return DropdownButtonFormField<int?>(
      // Rebuild when options load or the value is changed from outside (department -> branch).
      key: ValueKey('$label-${options.length}-$value'),
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: _decoration(label, error),
      items: [
        const DropdownMenuItem(value: null, child: Text('Select')),
        for (final (id, name) in options)
          DropdownMenuItem(
            value: id,
            child: Text(name, overflow: .ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

// =====================================================================
// Users (web: users.php)
// =====================================================================

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context) => MasterListPage<AppUser>(
    title: 'Users',
    list: usersProvider,
    mutation: userMutationProvider.notifier,
    tile: (u) => (
      icon: u.roleIsSystem ? Icons.admin_panel_settings_outlined : Icons.person_outline,
      title: u.name,
      code: null,
      lines: [
        ['@${u.username}', ?u.roleName].join(' · '),
        [
          if (u.employeeName != null) 'Employee: ${u.employeeName}',
          ?u.branchName,
          if (u.lastLogin != null) 'Last login ${fmtDateTime(u.lastLogin)}',
        ].join(' · '),
      ].where((l) => l.isNotEmpty).toList(),
    ),
    form: (u) => _UserForm(item: u),
  );
}

class _UserForm extends ConsumerStatefulWidget {
  const _UserForm({this.item});

  final AppUser? item;

  @override
  ConsumerState<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends ConsumerState<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _username = TextEditingController(text: widget.item?.username);
  late final _email = TextEditingController(text: widget.item?.email);
  final _password = TextEditingController();
  late int? _roleId = widget.item?.roleId;
  late int? _employeeId = widget.item?.employeeId;
  late int? _branchId = widget.item == null ? 1 : widget.item!.branchId;
  late bool _active = widget.item?.active ?? true;
  bool _showPassword = false;

  bool get _creating => widget.item == null;

  @override
  void dispose() {
    for (final c in [_name, _username, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_roleId == null) return;
    final saved = await ref
        .read(userMutationProvider.notifier)
        .save(
          AppUser(
            id: widget.item?.id,
            name: _name.text.trim(),
            username: _username.text.trim(),
            email: _opt(_email),
            password: _password.text.isEmpty ? null : _password.text,
            roleId: _roleId!,
            employeeId: _employeeId,
            branchId: _branchId,
            active: _active,
          ),
        );
    if (saved != null && mounted) {
      Navigator.of(context).pop(_creating ? 'Saved successfully' : 'Updated successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userMutationProvider);
    final err = state.error;
    final roles = ref.watch(rolesProvider).value ?? const <Role>[];
    final employees = ref.watch(employeesProvider).value ?? const <Employee>[];
    final branches = ref.watch(branchesProvider).value ?? const <Branch>[];

    // New users default to the Receptionist role, like the web.
    if (_roleId == null && roles.isNotEmpty) {
      _roleId = (roles.where((r) => r.slug == 'receptionist').firstOrNull ?? roles.first).id;
    }
    final role = roles.where((r) => r.id == _roleId).firstOrNull;
    final roleHelp = [
      ?role?.description,
      if (role != null && role.needsEmployee) 'This role only sees its own visits - link the user to an employee.',
    ].join(' ');

    return MasterFormSheet(
      formKey: _formKey,
      title: _creating ? 'Add User' : 'Edit User',
      saving: state.isLoading,
      failure: err,
      onSave: _save,
      children: [
        TextFormField(
          controller: _name,
          maxLength: 150,
          decoration: _decoration('Name *', masterFieldError(err, 'name')),
          validator: (v) => Validators.required(v, 'Name'),
        ),
        TextFormField(
          controller: _username,
          maxLength: 60,
          autocorrect: false,
          decoration: _decoration('Username *', masterFieldError(err, 'username')),
          validator: (v) => (v ?? '').trim().length < 3 ? 'At least 3 characters' : null,
        ),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _decoration('Email', masterFieldError(err, 'email')),
          validator: Validators.email,
        ),
        TextFormField(
          controller: _password,
          obscureText: !_showPassword,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: _creating ? 'Password *' : 'Password',
            helperText: _creating ? null : 'Leave blank to keep current password',
            errorText: masterFieldError(err, 'password'),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          validator: (v) {
            if ((v ?? '').isEmpty) return _creating ? 'Password is required' : null;
            return v!.length < 6 ? 'At least 6 characters' : null;
          },
        ),
        _IdDropdown(
          label: 'Role *',
          value: _roleId,
          error: masterFieldError(err, 'role_id'),
          options: [for (final r in roles) (r.id!, r.name)],
          onChanged: (v) => setState(() => _roleId = v),
        ),
        if (roleHelp.isNotEmpty) Text(roleHelp, style: Theme.of(context).textTheme.bodySmall),
        _IdDropdown(
          label: 'Linked Employee',
          value: _employeeId,
          error: masterFieldError(err, 'employee_id'),
          options: [for (final e in employees) (e.id!, '${e.name} (${e.code})')],
          onChanged: (v) => _employeeId = v,
        ),
        _IdDropdown(
          label: 'Branch',
          value: _branchId,
          error: masterFieldError(err, 'branch_id'),
          options: [for (final b in branches) (b.id!, b.name)],
          onChanged: (v) => _branchId = v,
        ),
        ActiveSwitch(value: _active, onChanged: (v) => setState(() => _active = v)),
      ],
    );
  }
}
