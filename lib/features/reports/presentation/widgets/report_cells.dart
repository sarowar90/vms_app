import '../../../../shared/data/json_utils.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../domain/report_entities.dart';

const _dateColumns = {'check_in_at', 'check_out_at', 'scheduled_at', 'created_at'};

/// Display text for a raw report value (web: `cell()` in reports.js).
String formatReportCell(String key, String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (_dateColumns.contains(key)) return fmtDateTime(parseDateTime(raw));
  return switch (key) {
    'status' => VisitStatus.fromValue(raw).label,
    'visit_type' => VisitType.fromValue(raw)?.label ?? raw,
    'checkin_method' => CheckinMethod.fromValue(raw)?.label ?? raw,
    _ => raw,
  };
}

/// Display text for a summary group value (web: `groupLabel()`).
String formatGroupLabel(ReportGroup group, String raw) => switch (group) {
  ReportGroup.visitType => VisitType.fromValue(raw)?.label ?? raw,
  ReportGroup.status => VisitStatus.fromValue(raw).label,
  ReportGroup.checkinMethod => CheckinMethod.fromValue(raw)?.label ?? raw,
  ReportGroup.date => fmtDate(parseDateTime(raw)),
  _ => raw,
};
