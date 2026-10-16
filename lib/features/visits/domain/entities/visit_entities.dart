import '../../../../shared/domain/entities/visit.dart';

/// An employee who can host visitors.
class Host {
  const Host({required this.id, required this.name, this.designation, this.departmentName});

  final int id;
  final String name;
  final String? designation;
  final String? departmentName;

  String get label =>
      [name, if (departmentName != null) '— $departmentName', if (designation != null) '($designation)'].join(' ');
}

/// A saved visitor profile (returned by the phone search).
class VisitorProfile {
  const VisitorProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.company,
    this.designation,
    this.address,
    this.idType,
    this.idNumber,
    this.gender,
    this.photoUrl,
    this.blacklisted = false,
    this.visitsCount,
    this.lastVisit,
    this.createdAt,
  });

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? company;
  final String? designation;
  final String? address;
  final IdType? idType;
  final String? idNumber;
  final Gender? gender;
  final String? photoUrl;
  final bool blacklisted;

  /// Only in the visitor list.
  final int? visitsCount;
  final DateTime? lastVisit;
  final DateTime? createdAt;

  /// e.g. `NID: 1990123456789`
  String? get idLabel => idNumber == null ? null : '${(idType ?? IdType.other).label}: $idNumber';
}

class BlacklistEntry {
  const BlacklistEntry({required this.name, this.reason});

  final String name;
  final String? reason;
}

/// Visitor fields sent with a walk-in or a pre-registration.
class VisitorInput {
  const VisitorInput({
    required this.phone,
    required this.name,
    this.email,
    this.company,
    this.designation,
    this.address,
    this.idType,
    this.idNumber,
    this.gender,
  });

  final String phone;
  final String name;
  final String? email;
  final String? company;
  final String? designation;
  final String? address;
  final IdType? idType;
  final String? idNumber;
  final Gender? gender;
}

/// Visit fields shared by walk-in check-in, pre-registration and edit.
class VisitDetails {
  const VisitDetails({
    required this.visitType,
    this.hostEmployeeId,
    this.purpose,
    this.personsCount = 1,
    this.carryingGoods,
    this.vehicleNo,
    this.cardNo,
    this.remarks,
  });

  /// `null` lets the server use the logged-in employee (users without `visits.view_all`).
  final int? hostEmployeeId;
  final VisitType visitType;
  final String? purpose;
  final int personsCount;
  final String? carryingGoods;
  final String? vehicleNo;
  final String? cardNo;
  final String? remarks;
}

/// POST /visits/checkin for a new walk-in visitor.
class WalkInCheckin {
  const WalkInCheckin({
    required this.visitor,
    required this.details,
    required this.method,
    this.holdForApproval = false,
    this.photoDataUri,
  });

  final VisitorInput visitor;
  final VisitDetails details;
  final CheckinMethod method;

  /// Register as pending and wait for the host instead of checking in now.
  final bool holdForApproval;

  /// `data:image/jpeg;base64,...`
  final String? photoDataUri;
}

/// POST /visits/checkin for an existing (pre-registered) visit.
class ExistingCheckin {
  const ExistingCheckin({
    required this.visitId,
    required this.method,
    this.cardNo,
    this.personsCount,
    this.carryingGoods,
    this.vehicleNo,
    this.remarks,
  });

  final int visitId;
  final CheckinMethod method;
  final String? cardNo;
  final int? personsCount;
  final String? carryingGoods;
  final String? vehicleNo;
  final String? remarks;
}

/// POST /visits (pre-register) or PUT /visits/{id} (edit).
class VisitForm {
  const VisitForm({required this.visitor, required this.details, required this.scheduledAt});

  final VisitorInput visitor;
  final VisitDetails details;
  final DateTime scheduledAt;
}

/// Filters for GET /visits. Value-equal, so it can key a provider family.
class VisitQuery {
  const VisitQuery({
    this.statuses = const [],
    this.q,
    this.visitType,
    this.from,
    this.to,
    this.page = 1,
    this.perPage = 25,
  });

  final List<VisitStatus> statuses;

  /// Name, mobile, company, visit no, visit code, purpose or host.
  final String? q;
  final VisitType? visitType;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int perPage;

  VisitQuery copyWith({int? page, int? perPage, List<VisitStatus>? statuses}) => VisitQuery(
    statuses: statuses ?? this.statuses,
    q: q,
    visitType: visitType,
    from: from,
    to: to,
    page: page ?? this.page,
    perPage: perPage ?? this.perPage,
  );

  @override
  bool operator ==(Object other) =>
      other is VisitQuery &&
      _sameList(other.statuses, statuses) &&
      other.q == q &&
      other.visitType == visitType &&
      other.from == from &&
      other.to == to &&
      other.page == page &&
      other.perPage == perPage;

  @override
  int get hashCode => Object.hash(Object.hashAll(statuses), q, visitType, from, to, page, perPage);

  static bool _sameList(List<VisitStatus> a, List<VisitStatus> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Workflow changes posted to `visits/{id}/{name}`.
enum VisitDecision { approve, reject, cancel, checkout }
