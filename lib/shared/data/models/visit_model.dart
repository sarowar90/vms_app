import '../../../core/config/app_config.dart';
import '../../domain/entities/visit.dart';
import '../json_utils.dart';

class VisitModel extends Visit {
  const VisitModel({
    required super.id,
    required super.visitNo,
    required super.visitCode,
    required super.visitorName,
    required super.hostName,
    required super.status,
    super.visitType,
    super.visitorPhone,
    super.visitorCompany,
    super.visitorPhotoUrl,
    super.hostDesignation,
    super.departmentName,
    super.branchName,
    super.purpose,
    super.personsCount,
    super.carryingGoods,
    super.vehicleNo,
    super.cardNo,
    super.checkinMethod,
    super.scheduledAt,
    super.checkInAt,
    super.checkOutAt,
    super.durationMinutes,
    super.remarks,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) => VisitModel(
        id: parseInt(json['id'])!,
        visitNo: json['visit_no']?.toString() ?? '',
        visitCode: json['visit_code']?.toString() ?? '',
        visitorName: json['visitor_name']?.toString() ?? '',
        visitorPhone: parseString(json['visitor_phone']),
        visitorCompany: parseString(json['visitor_company']),
        visitorPhotoUrl: AppConfig.resolveUrl(parseString(json['visitor_photo_url'])),
        hostName: json['host_name']?.toString() ?? '',
        hostDesignation: parseString(json['host_designation']),
        departmentName: parseString(json['department_name']),
        branchName: parseString(json['branch_name']),
        visitType: VisitType.fromValue(parseString(json['visit_type'])),
        purpose: parseString(json['purpose']),
        personsCount: parseInt(json['persons_count']) ?? 1,
        carryingGoods: parseString(json['carrying_goods']),
        vehicleNo: parseString(json['vehicle_no']),
        cardNo: parseString(json['card_no']),
        checkinMethod: CheckinMethod.fromValue(parseString(json['checkin_method'])),
        scheduledAt: parseDateTime(json['scheduled_at']),
        checkInAt: parseDateTime(json['check_in_at']),
        checkOutAt: parseDateTime(json['check_out_at']),
        durationMinutes: parseInt(json['duration_minutes']),
        status: VisitStatus.fromValue(parseString(json['status'])),
        remarks: parseString(json['remarks']),
      );
}
