import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/presentation/formatters.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/visit_entities.dart';
import '../providers/visit_action_providers.dart';
import '../widgets/visit_form_fields.dart';
import '../widgets/visitor_fields.dart';

/// Pre-register a visitor, or edit a visit (web: the visit form modal).
/// Pops with a success message.
class VisitFormPage extends ConsumerStatefulWidget {
  const VisitFormPage({super.key, this.visit});

  /// The visit to edit; `null` to pre-register a new one.
  final Visit? visit;

  static Future<String?> open(BuildContext context, {Visit? visit}) =>
      Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => VisitFormPage(visit: visit)));

  @override
  ConsumerState<VisitFormPage> createState() => _VisitFormPageState();
}

class _VisitFormPageState extends ConsumerState<VisitFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _visitor = VisitorFieldsController();
  final _purpose = TextEditingController();
  final _persons = TextEditingController(text: '1');
  final _goods = TextEditingController();
  final _vehicle = TextEditingController();
  final _cardNo = TextEditingController();
  final _remarks = TextEditingController();

  int? _hostId;
  VisitType _type = VisitType.meeting;
  late DateTime _scheduledAt;

  bool get _editing => widget.visit != null;

  @override
  void initState() {
    super.initState();
    final v = widget.visit;
    if (v == null) {
      // Next full hour, like the web form.
      final now = DateTime.now();
      _scheduledAt = DateTime(now.year, now.month, now.day, now.hour + 1);
      return;
    }
    _visitor.fillFromVisit(v);
    _hostId = v.hostEmployeeId;
    _type = v.visitType ?? VisitType.meeting;
    _scheduledAt = v.scheduledAt ?? DateTime.now();
    _purpose.text = v.purpose ?? '';
    _persons.text = '${v.personsCount}';
    _goods.text = v.carryingGoods ?? '';
    _vehicle.text = v.vehicleNo ?? '';
    _cardNo.text = v.cardNo ?? '';
    _remarks.text = v.remarks ?? '';
  }

  @override
  void dispose() {
    _visitor.dispose();
    for (final c in [_purpose, _persons, _goods, _vehicle, _cardNo, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt));
    if (time == null) return;
    setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _submit({required bool chooseHost}) async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (chooseHost && _hostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a host')));
      return;
    }
    final saved = await ref
        .read(visitFormSubmitProvider.notifier)
        .save(
          id: widget.visit?.id,
          form: VisitForm(
            visitor: _visitor.toInput(),
            scheduledAt: _scheduledAt,
            details: VisitDetails(
              hostEmployeeId: chooseHost ? _hostId : null,
              visitType: _type,
              purpose: _opt(_purpose),
              personsCount: int.tryParse(_persons.text) ?? 1,
              carryingGoods: _opt(_goods),
              vehicleNo: _opt(_vehicle),
              cardNo: _opt(_cardNo),
              remarks: _opt(_remarks),
            ),
          ),
        );
    if (!mounted) return;
    if (saved != null) {
      Navigator.of(context).pop(
        _editing
            ? 'Updated successfully'
            : saved.status == VisitStatus.approved
            ? 'Visit pre-registered and approved'
            : 'Visit pre-registered, waiting for approval',
      );
      return;
    }
    final failure = ref.read(visitFormSubmitProvider).error;
    if (failure is ServerFailure && failure.isBlacklisted) {
      _visitor.blacklist.value = BlacklistEntry(name: _visitor.name.text);
    }
    final text = switch (failure) {
      ServerFailure(statusCode: 422, errors: final e?) when e.isNotEmpty && !failure.isBlacklisted =>
        'Please fix the highlighted fields',
      final Failure f => f.message,
      _ => 'Something went wrong',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final submit = ref.watch(visitFormSubmitProvider);
    final failure = submit.error is Failure ? submit.error as Failure : null;
    String? err(String f) => failure is ServerFailure ? failure.fieldError(f) : null;

    // Users who only see their own visits always invite guests for themselves (server enforces this).
    final chooseHost = user?.can('visits.view_all') ?? false;
    final staff = user?.can('visits.checkin') ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Visit' : 'Pre-register Visitor')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              title: 'Visitor Info',
              icon: Icons.person_outline,
              children: [
                VisitorFields(
                  controller: _visitor,
                  failure: failure,
                  searchEnabled: !_editing,
                  showGenderAndAddress: false,
                ),
              ],
            ),
            const SizedBox(height: 12),
            FormSection(
              title: 'Visit Info',
              icon: Icons.work_outline,
              children: [
                if (chooseHost)
                  HostPicker(value: _hostId, errorText: err('host_employee_id'), onChanged: (v) => _hostId = v),
                VisitTypeDropdown(value: _type, onChanged: (v) => _type = v),
                InkWell(
                  onTap: _pickDateTime,
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: _editing ? 'Scheduled At' : 'Scheduled At *',
                      errorText: err('scheduled_at'),
                      border: const OutlineInputBorder(),
                      suffixIcon: const Icon(Icons.event),
                    ),
                    child: Text(fmtDateTime(_scheduledAt)),
                  ),
                ),
                _field(
                  _persons,
                  'Persons',
                  err('persons_count'),
                  keyboard: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null,
                ),
                _field(_purpose, 'Purpose', err('purpose')),
                _field(_goods, 'Carrying Goods', err('carrying_goods')),
                _field(_vehicle, 'Vehicle No', err('vehicle_no')),
                if (staff) _field(_cardNo, 'Card No', err('card_no')),
                _field(_remarks, 'Remarks', err('remarks'), maxLines: 2),
              ],
            ),
            const SizedBox(height: 12),
            if (failure != null && (failure is! ServerFailure || failure.errors == null)) ...[
              FormErrorText(failure.message),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: submit.isLoading ? null : () => _submit(chooseHost: chooseHost),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: submit.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Save'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    String? errorText, {
    TextInputType? keyboard,
    int maxLines = 1,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: c,
    keyboardType: keyboard,
    maxLines: maxLines,
    validator: validator,
    decoration: InputDecoration(labelText: label, errorText: errorText, border: const OutlineInputBorder()),
  );
}
