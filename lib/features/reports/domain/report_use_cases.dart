import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import 'report_entities.dart';
import 'report_repository.dart';

/// Quick date ranges of the report page.
enum ReportRange {
  today('Today'),
  week('This Week'),
  month('This Month'),
  year('This Year');

  const ReportRange(this.label);

  final String label;

  /// From/to dates for [now]. The week starts on Saturday (Bangladesh), like the web.
  (DateTime, DateTime) dates(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportRange.today => (today, today),
      // DateTime.weekday: Mon=1 ... Sat=6, Sun=7 -> days since Saturday.
      ReportRange.week => (today.subtract(Duration(days: (now.weekday + 1) % 7)), today),
      ReportRange.month => (DateTime(now.year, now.month), today),
      ReportRange.year => (DateTime(now.year), today),
    };
  }
}

class GetReportColumns implements UseCase<List<ReportColumn>, NoParams> {
  const GetReportColumns(this._repo);

  final ReportRepository _repo;

  @override
  Future<Result<List<ReportColumn>>> call(NoParams params) => _repo.columns();
}

class GetReportPage implements UseCase<ReportPage, ({ReportFilter filter, ReportLayout layout, int page})> {
  const GetReportPage(this._repo);

  final ReportRepository _repo;

  @override
  Future<Result<ReportPage>> call(({ReportFilter filter, ReportLayout layout, int page}) p) =>
      _repo.visits(p.filter, p.layout, page: p.page);
}

class GetReportSummary implements UseCase<List<SummaryRow>, ({ReportFilter filter, ReportGroup group})> {
  const GetReportSummary(this._repo);

  final ReportRepository _repo;

  @override
  Future<Result<List<SummaryRow>>> call(({ReportFilter filter, ReportGroup group}) p) =>
      _repo.summary(p.filter, p.group);
}

class ExportReport implements UseCase<ExportFile, ({ReportFilter filter, ReportLayout layout, ExportFormat format})> {
  const ExportReport(this._repo);

  final ReportRepository _repo;

  @override
  Future<Result<ExportFile>> call(({ReportFilter filter, ReportLayout layout, ExportFormat format}) p) =>
      _repo.export(p.filter, p.layout, p.format);
}
