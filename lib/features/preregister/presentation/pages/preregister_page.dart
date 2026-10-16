import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../../visits/presentation/pages/visit_form_page.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../../visits/presentation/widgets/visit_tile.dart';
import '../providers/preregister_providers.dart';

/// Pre-registration (web: `preregister.php`): Pending / Upcoming / Rejected-Cancelled tabs.
class PreregisterPage extends ConsumerStatefulWidget {
  const PreregisterPage({super.key, this.openNew = false});

  /// Open the new pre-registration form right away (dashboard button).
  final bool openNew;

  @override
  ConsumerState<PreregisterPage> createState() => _PreregisterPageState();
}

class _PreregisterPageState extends ConsumerState<PreregisterPage> {
  @override
  void initState() {
    super.initState();
    if (widget.openNew) WidgetsBinding.instance.addPostFrameCallback((_) => _new());
  }

  Future<void> _new() async {
    final message = await VisitFormPage.open(context);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.watch(authProvider).value?.can('visits.preregister') ?? false;

    return DefaultTabController(
      length: PreregTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pre-registration'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final t in PreregTab.values) Tab(child: _TabLabel(t))],
          ),
        ),
        drawer: const AppDrawer(),
        floatingActionButton: canCreate
            ? FloatingActionButton.extended(
                onPressed: _new,
                icon: const Icon(Icons.event_available),
                label: const Text('Pre-register'),
              )
            : null,
        body: TabBarView(children: [for (final t in PreregTab.values) _VisitList(t)]),
      ),
    );
  }
}

class _TabLabel extends ConsumerWidget {
  const _TabLabel(this.tab);

  final PreregTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tab == PreregTab.closed) return Text(tab.label);
    final count = ref.watch(preregCountProvider(tab)).value ?? 0;
    return Row(
      mainAxisSize: .min,
      spacing: 6,
      children: [
        Text(tab.label),
        if (count > 0)
          Badge(
            label: Text(fmtNumber(count)),
            backgroundColor: tab == PreregTab.pending ? VisitStatus.pending.color : VisitStatus.approved.color,
          ),
      ],
    );
  }
}

class _VisitList extends ConsumerWidget {
  const _VisitList(this.tab);

  final PreregTab tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(visitListProvider(tab.query));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(visitListProvider(tab.query).future).then((_) {}, onError: (_) {}),
      child: AsyncValueView(
        value: list,
        onRetry: () => ref.invalidate(visitListProvider(tab.query)),
        data: (page) {
          if (page.items.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: Text('No records found')),
                ),
              ],
            );
          }
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 300) ref.read(visitListProvider(tab.query).notifier).loadMore();
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 88),
              itemCount: page.items.length + (page.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => i == page.items.length
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : VisitTile(page.items[i]),
            ),
          );
        },
      ),
    );
  }
}
