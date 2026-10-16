import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/domain/visit_rules.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../../shared/presentation/widgets/async_value_view.dart';
import '../../../../shared/presentation/widgets/status_chip.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/pages/qr_scanner_page.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../../../visits/presentation/widgets/visit_form_fields.dart';
import '../providers/checkin_providers.dart';
import 'checkin_success_dialog.dart';

/// Pre-registered / QR tab: find a visit by code, QR or today's list, then check in.
class PreRegisteredTab extends ConsumerStatefulWidget {
  const PreRegisteredTab({super.key, this.initialVisitId});

  /// Opened from another page's "Check-in" action.
  final int? initialVisitId;

  @override
  ConsumerState<PreRegisteredTab> createState() => _PreRegisteredTabState();
}

class _PreRegisteredTabState extends ConsumerState<PreRegisteredTab> with AutomaticKeepAliveClientMixin {
  final _code = TextEditingController();
  Visit? _visit;
  bool _looking = false;
  String? _lookupError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.initialVisitId case final id?) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(() => ref.read(getVisitProvider)(id)));
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load(Future<Result<Visit>> Function() fetch, {CheckinMethod method = CheckinMethod.manual}) async {
    setState(() {
      _looking = true;
      _lookupError = null;
    });
    final result = await fetch();
    if (!mounted) return;
    ref.read(preCheckinSubmitProvider.notifier).reset();
    setState(() {
      _looking = false;
      switch (result) {
        case Success(:final value):
          _visit = value;
          _method = method;
        case Error(:final failure):
          _lookupError = failure.message;
      }
    });
  }

  CheckinMethod _method = CheckinMethod.manual;

  void _lookup(String code, CheckinMethod method) {
    if (code.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    _load(() => ref.read(lookupVisitProvider)(code), method: method);
  }

  Future<void> _scan() async {
    final code = await QrScannerPage.scan(context);
    if (code == null || !mounted) return;
    _code.text = code;
    _lookup(code, CheckinMethod.qr);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final expected = ref.watch(expectedTodayProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(expectedTodayProvider.future).then((_) {}, onError: (_) {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: .stretch,
                spacing: 12,
                children: [
                  TextField(
                    controller: _code,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      labelText: 'Enter Visit Code / Visit No',
                      hintText: 'XXXXXXXX',
                      errorText: _lookupError,
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => _lookup(_code.text, CheckinMethod.manual),
                      ),
                    ),
                    // A USB/Bluetooth scanner types the 8-char code + Enter: treat it as QR, like the web.
                    onSubmitted: (v) => _lookup(v, v.trim().length == 8 ? CheckinMethod.qr : CheckinMethod.manual),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _scan,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR Code'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_looking)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_visit case final v?)
            _CheckinCard(
              key: ValueKey(v.id),
              visit: v,
              initialMethod: _method,
              onDone: () => setState(() {
                _visit = null;
                _code.clear();
              }),
            )
          else
            const _Hint(),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: .stretch,
              children: [
                ListTile(
                  title: const Text('Expected Today'),
                  trailing: expected.value == null
                      ? null
                      : Badge(
                          label: Text(fmtNumber(expected.value!.total)),
                          backgroundColor: VisitStatus.approved.color,
                        ),
                ),
                const Divider(height: 1),
                AsyncValueView(
                  value: expected,
                  onRetry: () => ref.invalidate(expectedTodayProvider),
                  data: (page) => page.items.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('No records found')),
                        )
                      : Column(
                          children: [
                            for (final v in page.items)
                              ListTile(
                                selected: v.id == _visit?.id,
                                leading: VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 18),
                                title: Text(v.visitorName),
                                subtitle: Text(
                                  '${v.scheduledAt == null ? '' : '${fmtTime(v.scheduledAt)} · '}${v.hostName}',
                                ),
                                trailing: StatusChip(v.status),
                                onTap: () => setState(() {
                                  _visit = v;
                                  _method = CheckinMethod.manual;
                                  _lookupError = null;
                                }),
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Icon(Icons.qr_code_2, size: 48, color: outline),
          const SizedBox(height: 8),
          Text(
            "Enter a visit code, scan a QR code or pick a visitor from today's expected list",
            textAlign: .center,
            style: TextStyle(color: outline),
          ),
        ],
      ),
    );
  }
}

/// Details of the selected visit plus the check-in fields.
class _CheckinCard extends ConsumerStatefulWidget {
  const _CheckinCard({super.key, required this.visit, required this.initialMethod, required this.onDone});

  final Visit visit;
  final CheckinMethod initialMethod;
  final VoidCallback onDone;

  @override
  ConsumerState<_CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends ConsumerState<_CheckinCard> {
  late CheckinMethod _method = widget.initialMethod;
  late final _cardNo = TextEditingController();
  late final _persons = TextEditingController(text: '${widget.visit.personsCount}');
  late final _goods = TextEditingController(text: widget.visit.carryingGoods ?? '');
  late final _vehicle = TextEditingController(text: widget.visit.vehicleNo ?? '');
  late final _remarks = TextEditingController();

  @override
  void dispose() {
    for (final c in [_cardNo, _persons, _goods, _vehicle, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final visit = await ref
        .read(preCheckinSubmitProvider.notifier)
        .existing(
          ExistingCheckin(
            visitId: widget.visit.id,
            method: _method,
            cardNo: _opt(_cardNo),
            personsCount: int.tryParse(_persons.text),
            carryingGoods: _opt(_goods),
            vehicleNo: _opt(_vehicle),
            remarks: _opt(_remarks),
          ),
        );
    if (!mounted) return;
    if (visit != null) {
      widget.onDone();
      await showCheckinSuccess(context, visit);
    }
  }

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;
    final user = ref.watch(authProvider).value;
    final submit = ref.watch(preCheckinSubmitProvider);
    final failure = submit.error is Failure ? submit.error as Failure : null;
    String? err(String f) => failure is ServerFailure ? failure.fieldError(f) : null;
    final theme = Theme.of(context);

    final canCheckin = user != null && canDoVisit(VisitAction.checkin, v, user);
    final warning = v.status == VisitStatus.pending
        ? 'This visit is waiting for host approval. Only an admin can check in now.'
        : !canCheckin
        ? 'Cannot check in. Current status: ${v.status.label}'
        : null;

    final details = [
      ('Visit No', v.visitNo),
      ('Visit Code', v.visitCode),
      ('Host', [v.hostName, ?v.departmentName].join(' — ')),
      if (v.visitType != null) ('Visit Type', v.visitType!.label),
      if (v.purpose != null) ('Purpose', v.purpose!),
      if (v.scheduledAt != null) ('Scheduled', fmtDateTime(v.scheduledAt)),
      if (v.remarks != null) ('Remarks', v.remarks!),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: .stretch,
          spacing: 12,
          children: [
            Row(
              children: [
                VisitorAvatar(name: v.visitorName, photoUrl: v.visitorPhotoUrl, radius: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      Text(v.visitorName, style: theme.textTheme.titleMedium),
                      Text(
                        [?v.visitorPhone, ?v.visitorCompany, ?v.visitorDesignation].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                StatusChip(v.status),
              ],
            ),
            for (final (label, value) in details)
              Row(
                crossAxisAlignment: .start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(label, style: TextStyle(color: theme.colorScheme.outline)),
                  ),
                  Expanded(child: Text(value)),
                ],
              ),
            if (warning != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: VisitStatus.pending.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(warning),
              ),
            if (canCheckin) ...[
              const Divider(),
              Text('Check-in Method', style: theme.textTheme.titleSmall),
              CheckinMethodSelector(value: _method, onChanged: (m) => setState(() => _method = m)),
              _field(
                _cardNo,
                _method == CheckinMethod.rfid ? 'Card No *' : 'Card No',
                err('card_no'),
                hint: 'Tap RFID card or type number',
              ),
              _field(_persons, 'Persons', err('persons_count'), keyboard: TextInputType.number),
              _field(_goods, 'Carrying Goods', err('carrying_goods')),
              _field(_vehicle, 'Vehicle No', err('vehicle_no')),
              _field(_remarks, 'Remarks', err('remarks'), maxLines: 2),
              if (failure != null && (failure is! ServerFailure || failure.errors == null))
                FormErrorText(failure.message),
              FilledButton.icon(
                key: const Key('pre-checkin-submit'),
                onPressed: submit.isLoading ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: submit.isLoading
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.login),
                label: const Text('Check-in'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String? errorText, {
    String? hint,
    TextInputType? keyboard,
    int maxLines = 1,
  }) => TextField(
    controller: c,
    keyboardType: keyboard,
    maxLines: maxLines,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      border: const OutlineInputBorder(),
    ),
  );
}
