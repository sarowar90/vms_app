import 'package:flutter/material.dart';

import '../../../shell/presentation/widgets/app_drawer.dart';
import '../widgets/pre_registered_tab.dart';
import '../widgets/walk_in_form.dart';

/// Check-in (web: `checkin.php`): Walk-in and Pre-registered / QR tabs.
class CheckinPage extends StatelessWidget {
  const CheckinPage({super.key, this.visitId});

  /// When set, opens the Pre-registered tab with this visit loaded.
  final int? visitId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: visitId == null ? 0 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Check-in'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.directions_walk), text: 'Walk-in Visitor'),
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Pre-registered / QR'),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: TabBarView(
          children: [
            const WalkInForm(),
            PreRegisteredTab(initialVisitId: visitId),
          ],
        ),
      ),
    );
  }
}
