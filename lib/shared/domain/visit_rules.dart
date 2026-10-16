import '../../features/auth/domain/entities/user.dart';
import 'entities/visit.dart';

enum VisitAction { approve, reject, checkin, checkout, pass, edit, cancel, delete }

/// Who may do what with a visit. Mirrors `web/assets/js/visits.js`,
/// which mirrors the server rules in `VisitController.php`.
bool canDoVisit(VisitAction action, Visit v, User u) {
  final isHost = u.employeeId != null && v.hostEmployeeId == u.employeeId;
  final isCreator = v.createdBy == u.id;
  return switch (action) {
    VisitAction.approve || VisitAction.reject => v.status == VisitStatus.pending && (u.can('visits.approve') || isHost),
    VisitAction.checkin =>
      u.can('visits.checkin') &&
          (v.status == VisitStatus.approved || (v.status == VisitStatus.pending && u.can('visits.approve'))),
    VisitAction.checkout => u.can('visits.checkin') && v.status == VisitStatus.checkedIn,
    VisitAction.pass => v.status == VisitStatus.checkedIn || v.status == VisitStatus.approved,
    VisitAction.cancel => v.isOpen && (u.can('visits.cancel') || isHost || isCreator),
    VisitAction.edit => u.can('visits.edit') || (v.isOpen && (isHost || isCreator)),
    VisitAction.delete => u.can('visits.delete'),
  };
}
