import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/result.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../../shared/domain/validators.dart';
import '../../../../shared/presentation/widgets/visitor_avatar.dart';
import '../../domain/entities/visit_entities.dart';
import '../providers/visit_providers.dart';

/// Holds the visitor part of a form, so pages can read, fill and reset it.
class VisitorFieldsController {
  final phone = TextEditingController();
  final name = TextEditingController();
  final email = TextEditingController();
  final company = TextEditingController();
  final designation = TextEditingController();
  final address = TextEditingController();
  final idNumber = TextEditingController();
  final idType = ValueNotifier<IdType?>(null);
  final gender = ValueNotifier<Gender?>(null);

  /// Set when the phone/ID matches the blacklist (by lookup or by a 403 on submit).
  final blacklist = ValueNotifier<BlacklistEntry?>(null);

  /// The saved profile picked from suggestions ("returning visitor").
  final picked = ValueNotifier<VisitorProfile?>(null);

  VisitorInput toInput() => VisitorInput(
    phone: phone.text.trim(),
    name: name.text.trim(),
    email: _opt(email),
    company: _opt(company),
    designation: _opt(designation),
    address: _opt(address),
    idType: idType.value,
    idNumber: _opt(idNumber),
    gender: gender.value,
  );

  /// [returning] shows the "Returning visitor" banner (picked from suggestions).
  void fillFromProfile(VisitorProfile p, {bool returning = true}) {
    phone.text = p.phone;
    name.text = p.name;
    email.text = p.email ?? '';
    company.text = p.company ?? '';
    designation.text = p.designation ?? '';
    address.text = p.address ?? '';
    idNumber.text = p.idNumber ?? '';
    idType.value = p.idType;
    gender.value = p.gender;
    if (returning) picked.value = p;
  }

  void fillFromVisit(Visit v) {
    phone.text = v.visitorPhone ?? '';
    name.text = v.visitorName;
    email.text = v.visitorEmail ?? '';
    company.text = v.visitorCompany ?? '';
    designation.text = v.visitorDesignation ?? '';
    idNumber.text = v.visitorIdNumber ?? '';
    idType.value = IdType.fromValue(v.visitorIdType);
  }

  void clear() {
    for (final c in [phone, name, email, company, designation, address, idNumber]) {
      c.clear();
    }
    idType.value = null;
    gender.value = null;
    blacklist.value = null;
    picked.value = null;
  }

  void dispose() {
    for (final c in [phone, name, email, company, designation, address, idNumber]) {
      c.dispose();
    }
    for (final n in [idType, gender, blacklist, picked]) {
      n.dispose();
    }
  }

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
}

/// Visitor info fields with returning-visitor search and blacklist warning,
/// like the web check-in / pre-registration forms.
class VisitorFields extends ConsumerStatefulWidget {
  const VisitorFields({
    super.key,
    required this.controller,
    this.failure,
    this.searchEnabled = true,
    this.showGenderAndAddress = true,
    this.onPicked,
  });

  final VisitorFieldsController controller;

  /// Last submit failure, for field errors.
  final Failure? failure;
  final bool searchEnabled;
  final bool showGenderAndAddress;
  final ValueChanged<VisitorProfile>? onPicked;

  @override
  ConsumerState<VisitorFields> createState() => _VisitorFieldsState();
}

class _VisitorFieldsState extends ConsumerState<VisitorFields> {
  Timer? _debounce;
  List<VisitorProfile> _suggestions = const [];
  int _searchSeq = 0;

  VisitorFieldsController get c => widget.controller;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String value) async {
    final seq = ++_searchSeq;
    if (widget.searchEnabled && c.picked.value == null) {
      final result = await ref.read(searchVisitorsProvider)(value);
      if (!mounted || seq != _searchSeq) return;
      setState(() => _suggestions = result.fold((_) => const [], (list) => list));
    }
    // Blacklist check once a full number is typed.
    final hit = await ref.read(checkBlacklistProvider)((phone: value, idNumber: null));
    if (!mounted || seq != _searchSeq) return;
    if (hit case Success(:final value)) c.blacklist.value = value;
  }

  Future<void> _pick(VisitorProfile p) async {
    setState(() => _suggestions = const []);
    c.fillFromProfile(p);
    widget.onPicked?.call(p);
    FocusScope.of(context).unfocus();
    final hit = await ref.read(checkBlacklistProvider)((phone: p.phone, idNumber: p.idNumber));
    if (mounted && hit is Success<BlacklistEntry?>) c.blacklist.value = hit.value;
  }

  String? _err(String field) => switch (widget.failure) {
    ServerFailure f => f.fieldError(field),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: .stretch,
      spacing: 12,
      children: [
        ValueListenableBuilder(
          valueListenable: c.blacklist,
          builder: (_, entry, _) => entry == null
              ? const SizedBox.shrink()
              : _Banner(
                  color: scheme.error,
                  icon: Icons.block,
                  text: 'This visitor is BLACKLISTED${entry.reason != null ? ' (${entry.reason})' : ''}',
                ),
        ),
        ValueListenableBuilder(
          valueListenable: c.picked,
          builder: (_, p, _) => p == null
              ? const SizedBox.shrink()
              : _Banner(
                  color: const Color(0xFF0B7D93),
                  icon: Icons.history,
                  text: 'Returning visitor',
                  action: TextButton(
                    onPressed: () {
                      c.clear();
                      setState(() => _suggestions = const []);
                    },
                    child: const Text('New visitor'),
                  ),
                ),
        ),
        TextFormField(
          controller: c.phone,
          keyboardType: TextInputType.phone,
          maxLength: 14,
          decoration: InputDecoration(
            labelText: 'Mobile *',
            prefixText: '+88 ',
            hintText: '01XXXXXXXXX',
            helperText: widget.searchEnabled ? 'Type 4+ digits to find a returning visitor' : null,
            counterText: '',
            errorText: _err('phone'),
            border: const OutlineInputBorder(),
          ),
          validator: Validators.bdPhone,
          onChanged: _onPhoneChanged,
        ),
        if (_suggestions.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final s in _suggestions)
                  ListTile(
                    dense: true,
                    leading: VisitorAvatar(name: s.name, photoUrl: s.photoUrl, radius: 16),
                    title: Row(
                      children: [
                        Flexible(child: Text(s.name, overflow: .ellipsis)),
                        if (s.blacklisted) ...[
                          const SizedBox(width: 6),
                          Text(
                            'BLACKLISTED',
                            style: TextStyle(color: scheme.error, fontSize: 11, fontWeight: .w700),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text([s.phone, ?s.company].join(' · ')),
                    onTap: () => _pick(s),
                  ),
              ],
            ),
          ),
        _text(c.name, 'Visitor Name *', 'name', validator: (v) => Validators.required(v, 'Name')),
        _text(c.email, 'Email', 'email', keyboard: TextInputType.emailAddress, validator: Validators.email),
        _text(c.company, 'Company', 'company'),
        _text(c.designation, 'Designation', 'designation'),
        if (widget.showGenderAndAddress)
          ValueListenableBuilder(
            valueListenable: c.gender,
            builder: (_, g, _) => DropdownButtonFormField<Gender?>(
              // initialValue is only read once; the key rebuilds it when the value is filled in.
              key: ValueKey(g),
              initialValue: g,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(value: null, child: Text('Select')),
                for (final x in Gender.values) DropdownMenuItem(value: x, child: Text(x.label)),
              ],
              onChanged: (v) => c.gender.value = v,
            ),
          ),
        Row(
          crossAxisAlignment: .start,
          spacing: 12,
          children: [
            Expanded(
              flex: 2,
              child: ValueListenableBuilder(
                valueListenable: c.idType,
                builder: (_, t, _) => DropdownButtonFormField<IdType?>(
                  key: ValueKey(t),
                  initialValue: t,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'ID Type', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Select')),
                    for (final x in IdType.values) DropdownMenuItem(value: x, child: Text(x.label)),
                  ],
                  onChanged: (v) => c.idType.value = v,
                ),
              ),
            ),
            Expanded(flex: 3, child: _text(c.idNumber, 'ID Number', 'id_number')),
          ],
        ),
        if (widget.showGenderAndAddress) _text(c.address, 'Address', 'address'),
      ],
    );
  }

  Widget _text(
    TextEditingController controller,
    String label,
    String field, {
    TextInputType? keyboard,
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboard,
    decoration: InputDecoration(labelText: label, errorText: _err(field), border: const OutlineInputBorder()),
    validator: validator,
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.icon, required this.text, this.action});

  final Color color;
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: .w600),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
