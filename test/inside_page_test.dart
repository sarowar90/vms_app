import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vms_app/app.dart';
import 'package:vms_app/core/error/failures.dart';
import 'package:vms_app/core/router/app_router.dart';
import 'package:vms_app/core/storage/storage_providers.dart';
import 'package:vms_app/core/utils/result.dart';
import 'package:vms_app/features/auth/domain/entities/user.dart';
import 'package:vms_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:vms_app/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:vms_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:vms_app/features/visits/domain/repositories/visit_repository.dart';
import 'package:vms_app/features/visits/presentation/providers/visit_providers.dart';
import 'package:vms_app/shared/domain/entities/visit.dart';

const _guard = User(
  id: 20,
  name: 'Gate Security',
  username: 'security',
  role: 'security',
  roleName: 'Gate Security',
  permissions: ['visits.checkin', 'blacklist.view'],
  isSuperAdmin: false,
  company: Company(id: 1, name: 'ABC Group Ltd.', code: 'ABC'),
);

Visit _inside(int id, String name, {int persons = 1, String? card}) => Visit(
  id: id,
  visitNo: 'V-$id',
  visitCode: 'CODE000$id',
  visitorName: name,
  visitorPhone: '0171100000$id',
  hostName: 'Farhana Islam',
  status: VisitStatus.checkedIn,
  checkinMethod: card == null ? CheckinMethod.manual : CheckinMethod.rfid,
  cardNo: card,
  personsCount: persons,
  checkInAt: DateTime(2026, 10, 16, 9, 30),
  durationMinutes: 75,
);

class _FakeVisits implements VisitRepository {
  final inside = [_inside(1, 'Ayesha Siddika'), _inside(2, 'Abul Kalam Azad', persons: 2, card: 'RF-1007')];
  final checkedOut = <String>[];

  @override
  Future<Result<List<Visit>>> activeVisits() async => Success(List.of(inside));

  @override
  Future<Result<Visit>> checkoutByCode(String code) async {
    final i = inside.indexWhere((v) => v.visitCode == code || v.cardNo == code);
    if (i < 0) return const Error(ServerFailure('No checked-in visit found for this code', statusCode: 404));
    checkedOut.add(code);
    final v = inside.removeAt(i);
    return Success(
      Visit(
        id: v.id,
        visitNo: v.visitNo,
        visitCode: v.visitCode,
        visitorName: v.visitorName,
        hostName: v.hostName,
        status: VisitStatus.checkedOut,
        durationMinutes: 75,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends AuthNotifier {
  @override
  Future<User?> build() async => _guard;
}

void main() {
  testWidgets('Inside page: counters, search, quick check-out by RFID card', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 780 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FakeVisits();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(_FakeAuth.new),
        visitRepositoryProvider.overrideWithValue(repo),
        dashboardRepositoryProvider.overrideWithValue(_OfflineDashboard()),
      ],
    );
    // Disposed explicitly at the end so auto-refresh timers are cancelled.
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const VmsApp()));
    await tester.pumpAndSettle();
    container.read(appRouterProvider).go('/active');
    await tester.pumpAndSettle();

    expect(find.text('Quick Check-out'), findsOneWidget);
    expect(find.text('Ayesha Siddika'), findsOneWidget);
    expect(find.text('Abul Kalam Azad'), findsOneWidget);
    expect(find.text('1h 15m'), findsNWidgets(2));
    // Inside Now = 2 visits, Persons = 1 + 2.
    expect(find.text('3'), findsOneWidget);

    // Search filters the list locally.
    await tester.enterText(find.widgetWithText(TextField, 'Search'), 'RF-1007');
    await tester.pump();
    expect(find.text('Ayesha Siddika'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'Search'), '');
    await tester.pump();

    // Unknown code shows the server message.
    await tester.enterText(find.widgetWithText(TextField, 'CODE / CARD'), 'NOPE');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('No checked-in visit found for this code'), findsOneWidget);

    // RFID card tap checks the visitor out and the list reloads.
    await tester.enterText(find.widgetWithText(TextField, 'CODE / CARD'), 'RF-1007');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.checkedOut, ['RF-1007']);
    expect(find.text('Checked out successfully: Abul Kalam Azad (1h 15m)'), findsOneWidget);
    expect(find.text('Abul Kalam Azad'), findsNothing);

    // Let the snackbar finish, then unmount so the auto-refresh timer is cancelled.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    await tester.pump();
  });
}

/// The app starts on the dashboard; keep it off the network.
class _OfflineDashboard implements DashboardRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(const Error<Never>(NetworkFailure()));
}
