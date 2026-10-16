import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../visitor_providers.dart';
import 'visitor_profile_page.dart';

/// Visitor Profiles (web: `visitors.php`): searchable list of saved visitors.
class VisitorsPage extends ConsumerStatefulWidget {
  const VisitorsPage({super.key});

  @override
  ConsumerState<VisitorsPage> createState() => _VisitorsPageState();
}

class _VisitorsPageState extends ConsumerState<VisitorsPage> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(visitorSearchProvider.notifier).set(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(visitorListProvider);
    final total = list.value?.total;

    return Scaffold(
      appBar: AppBar(title: Text(total == null ? 'Visitor Profiles' : 'Visitor Profiles (${fmtNumber(total)})')),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search name, mobile, NID, company...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(visitorListProvider.future).then((_) {}, onError: (_) {}),
              child: AsyncValueView(
                value: list,
                onRetry: () => ref.invalidate(visitorListProvider),
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
                      if (n.metrics.extentAfter < 300) ref.read(visitorListProvider.notifier).loadMore();
                      return false;
                    },
                    child: ListView.separated(
                      itemCount: page.items.length + (page.hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => i == page.items.length
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _VisitorTile(page.items[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile(this.v);

  final VisitorProfile v;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: VisitorAvatar(name: v.name, photoUrl: v.photoUrl, radius: 22),
      title: Text(v.name, style: const TextStyle(fontWeight: .w600)),
      subtitle: Column(
        crossAxisAlignment: .start,
        children: [
          Text([v.phone, ?v.company].join(' · ')),
          if (v.designation != null || v.idLabel != null) Text([?v.designation, ?v.idLabel].join(' · '), style: muted),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: .center,
        crossAxisAlignment: .end,
        children: [
          Text('${fmtNumber(v.visitsCount ?? 0)} visits', style: theme.textTheme.labelMedium),
          if (v.lastVisit != null) Text(fmtDate(v.lastVisit), style: muted),
        ],
      ),
      onTap: () => VisitorProfilePage.open(context, v.id),
    );
  }
}
