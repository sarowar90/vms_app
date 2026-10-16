import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/confirm_dialog.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../shell/presentation/widgets/app_drawer.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/pages/qr_scanner_page.dart';
import '../../../visits/presentation/pages/visitor_pass_page.dart';
import '../../../visits/presentation/providers/visit_action_providers.dart';
import '../../../visits/presentation/widgets/visit_actions_sheet.dart';
import '../inside_providers.dart';

const _checkoutColor = Color(0xFFF4A300);

/// Inside / Check-out (web: `active-visits.php`): who is inside now, quick
/// check-out by QR / code / RFID card, and per-visitor check-out.
class InsidePage extends ConsumerStatefulWidget {
  const InsidePage({super.key});

  @override
  ConsumerState<InsidePage> createState() => _InsidePageState();
}

class _InsidePageState extends ConsumerState<InsidePage> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  String _filter = '';

  @override
  void dispose() {
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _quickCheckout(String code) async {
    if (code.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final v = await ref.read(quickCheckoutProvider.notifier).submit(code);
    if (!mounted) return;
    if (v != null) {
      _code.clear();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_doneText(v))));
    } else {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${ref.read(quickCheckoutProvider).error}')));
    }
    // Ready for the next scan / card tap (a USB/Bluetooth reader types into this field).
    _codeFocus.requestFocus();
  }

  Future<void> _scan() async {
    final code = await QrScannerPage.scan(context);
    if (code != null && mounted) await _quickCheckout(code);
  }

  Future<void> _checkout(Visit v) async {
    final remarks = await askRemarks(
      context,
      title: 'Check out ${v.visitorName} now?',
      okText: 'Check-out',
      inputLabel: 'Remarks (optional)',
      color: _checkoutColor,
    );
    if (remarks == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final done = await ref.read(visitActionProvider.notifier).decide(v.id, VisitDecision.checkout, remarks: remarks);
    messenger.showSnackBar(
      SnackBar(content: Text(done != null ? _doneText(done) : '${ref.read(visitActionProvider).error}')),
    );
  }

  static String _doneText(Visit v) =>
      'Checked out successfully: ${v.visitorName}'
      '${v.durationMinutes == null ? '' : ' (${fmtDuration(v.durationMinutes!)})'}';

  bool _matches(Visit v) {
    if (_filter.isEmpty) return true;
    final q = _filter.toLowerCase();
    return [
      v.visitorName,
      v.visitorPhone,
      v.visitorCompany,
      v.hostName,
      v.visitNo,
      v.cardNo,
    ].any((s) => s != null && s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeVisitsProvider);
    final quick = ref.watch(quickCheckoutProvider);
    // Keep the auto-dispose per-row check-out notifier alive while this page is open.
    ref.watch(visitActionProvider);
    final list = active.value;
    final persons = list?.fold<int>(0, (sum, v) => sum + v.personsCount);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inside / Check-out'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(activeVisitsProvider),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(activeVisitsProvider.future).then((_) {}, onError: (_) {}),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: .stretch,
                    spacing: 12,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.logout, color: _checkoutColor),
                          const SizedBox(width: 8),
                          Text('Quick Check-out', style: theme.textTheme.titleSmall),
                        ],
                      ),
                      Text(
                        'Scan the pass QR code, type the visit code / visit no, or tap the RFID card.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      TextField(
                        controller: _code,
                        focusNode: _codeFocus,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _quickCheckout,
                        decoration: InputDecoration(
                          hintText: 'CODE / CARD',
                          border: const OutlineInputBorder(),
                          suffixIcon: quick.isLoading
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'Check-out',
                                  icon: const Icon(Icons.logout, color: _checkoutColor),
                                  onPressed: () => _quickCheckout(_code.text),
                                ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: quick.isLoading ? null : _scan,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR Code'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: _Counter(
                      label: 'Inside Now',
                      value: list?.length,
                      icon: Icons.meeting_room_outlined,
                      color: VisitStatus.checkedIn.color,
                    ),
                  ),
                  Expanded(
                    child: _Counter(
                      label: 'Persons',
                      value: persons,
                      icon: Icons.groups_outlined,
                      color: const Color(0xFF1D5FC1),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _filter = v.trim()),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ),
            AsyncValueView(
              value: active,
              onRetry: () => ref.invalidate(activeVisitsProvider),
              data: (all) {
                final items = all.where(_matches).toList();
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: Text('No records found')),
                  );
                }
                return Column(
                  children: [
                    for (final v in items) ...[
                      const Divider(height: 1),
                      _InsideTile(visit: v, onCheckout: () => _checkout(v)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final int? value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  Text(
                    value == null ? '–' : fmtNumber(value!),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: .w700),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: .ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsideTile extends StatelessWidget {
  const _InsideTile({required this.visit, required this.onCheckout});

  final Visit visit;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline);

    return InkWell(
      onTap: () => showVisitActionsSheet(context, v),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                spacing: 2,
                children: [
                  Text(
                    v.visitorName,
                    style: const TextStyle(fontWeight: .w600),
                    overflow: .ellipsis,
                  ),
                  Text([?v.visitorPhone, ?v.visitorCompany].join(' · '), style: muted, overflow: .ellipsis),
                  Text(
                    ['Host: ${v.hostName}', ?v.departmentName].join(' · '),
                    style: theme.textTheme.bodySmall,
                    overflow: .ellipsis,
                  ),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _Meta(Icons.login, fmtTime(v.checkInAt)),
                      if (v.durationMinutes != null) _Meta(Icons.hourglass_bottom, fmtDuration(v.durationMinutes!)),
                      if (v.checkinMethod != null) _Meta(v.checkinMethod!.icon, v.checkinMethod!.label),
                      if (v.cardNo != null) _Meta(Icons.credit_card, v.cardNo!),
                      if (v.personsCount > 1) _Meta(Icons.groups_outlined, '${v.personsCount}'),
                    ],
                  ),
                  // Actions on their own line so details keep the full width on small phones.
                  Row(
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _checkoutColor,
                          foregroundColor: Colors.black87,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: onCheckout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Check-out'),
                      ),
                      IconButton(
                        tooltip: 'Visitor Pass',
                        icon: const Icon(Icons.qr_code),
                        onPressed: () => VisitorPassPage.open(context, v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: .min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color),
            overflow: .ellipsis,
          ),
        ),
      ],
    );
  }
}
