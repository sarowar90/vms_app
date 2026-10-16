import '../../../core/utils/result.dart';
import 'report_entities.dart';

abstract interface class ReportRepository {
  Future<Result<List<ReportColumn>>> columns();

  Future<Result<ReportPage>> visits(ReportFilter filter, ReportLayout layout, {int page = 1, int perPage = 50});

  Future<Result<List<SummaryRow>>> summary(ReportFilter filter, ReportGroup group);

  /// Downloads the report as a file (needs `reports.export`).
  Future<Result<ExportFile>> export(ReportFilter filter, ReportLayout layout, ExportFormat format);

  Future<Result<List<NamedOption>>> departments();

  Future<Result<List<NamedOption>>> branches();

  // ---- Stored on this device (web: localStorage) ----

  ReportLayout? savedLayout();

  Future<void> saveLayout(ReportLayout layout);

  List<ReportPreset> presets();

  Future<void> savePresets(List<ReportPreset> presets);
}
