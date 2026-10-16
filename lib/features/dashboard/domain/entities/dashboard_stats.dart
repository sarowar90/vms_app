import '../../../../shared/domain/entities/visit.dart';

class DashboardStats {
  const DashboardStats({
    required this.todayCheckins,
    required this.insideNow,
    required this.todayCheckouts,
    required this.pendingApprovals,
    required this.expectedToday,
    required this.todayPersons,
    required this.monthVisits,
    required this.totalVisitors,
    required this.recent,
  });

  final int todayCheckins;
  final int insideNow;
  final int todayCheckouts;
  final int pendingApprovals;
  final int expectedToday;
  final int todayPersons;
  final int monthVisits;
  final int totalVisitors;
  final List<Visit> recent;
}
