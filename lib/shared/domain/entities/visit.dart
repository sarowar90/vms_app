import 'package:flutter/material.dart';

/// A visit, shared by dashboard, visits, check-in and reports features.
class Visit {
  const Visit({
    required this.id,
    required this.visitNo,
    required this.visitCode,
    required this.visitorName,
    required this.hostName,
    required this.status,
    this.visitType,
    this.visitorPhone,
    this.visitorCompany,
    this.visitorPhotoUrl,
    this.hostDesignation,
    this.departmentName,
    this.branchName,
    this.purpose,
    this.personsCount = 1,
    this.carryingGoods,
    this.vehicleNo,
    this.cardNo,
    this.checkinMethod,
    this.scheduledAt,
    this.checkInAt,
    this.checkOutAt,
    this.durationMinutes,
    this.remarks,
  });

  final int id;
  final String visitNo;
  final String visitCode;
  final String visitorName;
  final String? visitorPhone;
  final String? visitorCompany;
  final String? visitorPhotoUrl;
  final String hostName;
  final String? hostDesignation;
  final String? departmentName;
  final String? branchName;
  final VisitType? visitType;
  final String? purpose;
  final int personsCount;
  final String? carryingGoods;
  final String? vehicleNo;
  final String? cardNo;
  final CheckinMethod? checkinMethod;
  final DateTime? scheduledAt;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final int? durationMinutes;
  final VisitStatus status;
  final String? remarks;
}

enum VisitStatus {
  pending('pending', 'Pending', Color(0xFFF4A300)),
  approved('approved', 'Approved', Color(0xFF0B7D93)),
  checkedIn('checked_in', 'Checked-in', Color(0xFF2E9E6A)),
  checkedOut('checked_out', 'Checked-out', Color(0xFF6C757D)),
  cancelled('cancelled', 'Cancelled', Color(0xFF343A40)),
  rejected('rejected', 'Rejected', Color(0xFFF42A41));

  const VisitStatus(this.value, this.label, this.color);

  final String value;
  final String label;
  final Color color;

  static VisitStatus fromValue(String? value) =>
      values.firstWhere((s) => s.value == value, orElse: () => pending);
}

enum VisitType {
  meeting('meeting', 'Meeting'),
  interview('interview', 'Interview'),
  delivery('delivery', 'Delivery'),
  service('service', 'Service'),
  vendor('vendor', 'Vendor'),
  other('other', 'Other');

  const VisitType(this.value, this.label);

  final String value;
  final String label;

  static VisitType? fromValue(String? value) =>
      value == null ? null : values.firstWhere((t) => t.value == value, orElse: () => other);
}

enum CheckinMethod {
  qr('qr', 'QR', Icons.qr_code, Color(0xFF006A4E)),
  manual('manual', 'Manual', Icons.edit_note, Color(0xFF1D5FC1)),
  rfid('rfid', 'RFID Card', Icons.credit_card, Color(0xFFD68A00));

  const CheckinMethod(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  static CheckinMethod? fromValue(String? value) {
    for (final m in values) {
      if (m.value == value) return m;
    }
    return null;
  }
}
