import 'package:flutter/material.dart';

/// Labels for `external_api/core/Permissions.php` (web: `perm_*` keys in lang/en.json).
const permissionLabels = <String, (String, String?)>{
  'visits.view_all': ('See all visits', 'Without this, the user only sees visits where they are the host'),
  'visits.checkin': ('Gate check-in / check-out', 'Check-in, check-out, inside list, QR / RFID lookup'),
  'visits.preregister': ('Pre-register visitors', 'Invite visitors in advance'),
  'visits.approve': (
    'Approve / reject any visit',
    'Own pre-registrations are approved automatically; can check in pending visits',
  ),
  'visits.edit': ('Edit any visit', 'Without this, only own pending/approved visits'),
  'visits.cancel': ('Cancel any visit', null),
  'visits.delete': ('Delete visits', null),
  'visitors.view': ('View & edit visitor profiles', null),
  'visitors.delete': ('Delete visitor profiles', null),
  'blacklist.view': ('View blacklist', null),
  'blacklist.manage': ('Add / remove blacklist entries', null),
  'reports.view': ('View reports', 'Limited to own visits without "See all visits"'),
  'reports.export': ('Export reports (Excel / CSV)', null),
  'masters.manage': ('Manage branches, departments & employees', null),
  'users.manage': ('Manage users', null),
  'roles.manage': ('Manage roles & permissions', null),
  'settings.manage': ('Company settings', null),
};

const permissionGroups = <String, (String, IconData)>{
  'visits': ('Visits', Icons.meeting_room_outlined),
  'visitors': ('Visitor Profiles', Icons.people_outline),
  'blacklist': ('Blacklist', Icons.block),
  'reports': ('Reports', Icons.assessment_outlined),
  'setup': ('Setup & Administration', Icons.settings_outlined),
};
