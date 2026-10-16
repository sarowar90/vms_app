import 'package:flutter/material.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const dashboard = '/';
  static const companies = '/companies';
  static const checkin = '/checkin';
  static const active = '/active';
  static const preregister = '/preregister';
  static const visits = '/visits';
  static const visitors = '/visitors';
  static const blacklist = '/blacklist';
  static const reports = '/reports';
  static const branches = '/branches';
  static const departments = '/departments';
  static const employees = '/employees';
  static const users = '/users';
  static const roles = '/roles';
  static const settings = '/settings';
}

/// One entry of the side menu, mirroring `web/includes/header.php`.
class NavItem {
  const NavItem(this.route, this.label, this.icon, {this.permissions = const [], this.group});

  final String route;
  final String label;
  final IconData icon;

  /// The user needs ANY of these. Empty means everyone in a company.
  final List<String> permissions;
  final String? group;
}

const superAdminNav = [
  NavItem(AppRoutes.companies, 'Companies', Icons.apartment, group: 'Platform'),
];

const companyNav = [
  NavItem(AppRoutes.dashboard, 'Dashboard', Icons.dashboard_outlined),
  NavItem(AppRoutes.checkin, 'Check-in', Icons.login,
      permissions: ['visits.checkin'], group: 'Visitors'),
  NavItem(AppRoutes.active, 'Inside / Check-out', Icons.meeting_room_outlined,
      permissions: ['visits.checkin'], group: 'Visitors'),
  NavItem(AppRoutes.preregister, 'Pre-registration', Icons.event_available, group: 'Visitors'),
  NavItem(AppRoutes.visits, 'All Visits', Icons.checklist, group: 'Visitors'),
  NavItem(AppRoutes.visitors, 'Visitor Profiles', Icons.people_outline,
      permissions: ['visitors.view'], group: 'Visitors'),
  NavItem(AppRoutes.blacklist, 'Blacklist', Icons.block,
      permissions: ['blacklist.view', 'blacklist.manage'], group: 'Visitors'),
  NavItem(AppRoutes.reports, 'Visitor Report', Icons.assessment_outlined,
      permissions: ['reports.view'], group: 'Reports'),
  NavItem(AppRoutes.branches, 'Branches', Icons.business,
      permissions: ['masters.manage'], group: 'Setup'),
  NavItem(AppRoutes.departments, 'Departments', Icons.account_tree_outlined,
      permissions: ['masters.manage'], group: 'Setup'),
  NavItem(AppRoutes.employees, 'Employees / Hosts', Icons.badge_outlined,
      permissions: ['masters.manage'], group: 'Setup'),
  NavItem(AppRoutes.users, 'Users', Icons.manage_accounts_outlined,
      permissions: ['users.manage'], group: 'Setup'),
  NavItem(AppRoutes.roles, 'Roles & Permissions', Icons.admin_panel_settings_outlined,
      permissions: ['roles.manage'], group: 'Setup'),
  NavItem(AppRoutes.settings, 'Settings', Icons.settings_outlined,
      permissions: ['settings.manage'], group: 'Setup'),
];
