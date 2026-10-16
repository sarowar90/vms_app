import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failures.dart';
import '../../../../shared/domain/entities/visit.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/widgets/visit_form_fields.dart';
import '../../../visits/presentation/widgets/visitor_fields.dart';
import '../providers/checkin_providers.dart';
import 'checkin_success_dialog.dart';

/// Walk-in tab: register a new or returning visitor and check in now.
class WalkInForm extends ConsumerStatefulWidget {
  const WalkInForm({super.key});

  @override
  ConsumerState<WalkInForm> createState() => _WalkInFormState();
}

class _WalkInFormState extends ConsumerState<WalkInForm> with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _visitor = VisitorFieldsController();
  final _purpose = TextEditingController();
  final _persons = TextEditingController(text: '1');
  final _goods = TextEditingController();
  final _vehicle = TextEditingController();
  final _remarks = TextEditingController();
  final _cardNo = TextEditingController();

  int? _hostId;
  VisitType _type = VisitType.meeting;
  CheckinMethod _method = CheckinMethod.manual;
  bool _hold = false;
  Uint8List? _photo;
  String? _existingPhotoUrl;

  /// Incremented on reset so dropdowns rebuild with their initial values.
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _visitor.dispose();
    for (final c in [_purpose, _persons, _goods, _vehicle, _remarks, _cardNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _takePhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  void _reset() {
    _visitor.clear();
    for (final c in [_purpose, _goods, _vehicle, _remarks, _cardNo]) {
      c.clear();
    }
    _persons.text = '1';
    setState(() {
      _hostId = null;
      _type = VisitType.meeting;
      _method = CheckinMethod.manual;
      _hold = false;
      _photo = null;
      _existingPhotoUrl = null;
      _generation++;
    });
    ref.read(walkInSubmitProvider.notifier).reset();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_hostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a host')));
      return;
    }
    final visit = await ref
        .read(walkInSubmitProvider.notifier)
        .walkIn(
          WalkInCheckin(
            visitor: _visitor.toInput(),
            details: VisitDetails(
              hostEmployeeId: _hostId,
              visitType: _type,
              purpose: _opt(_purpose),
              personsCount: int.tryParse(_persons.text) ?? 1,
              carryingGoods: _opt(_goods),
              vehicleNo: _opt(_vehicle),
              cardNo: _opt(_cardNo),
              remarks: _opt(_remarks),
            ),
            method: _method,
            holdForApproval: _hold,
            photoDataUri: _photo == null ? null : 'data:image/jpeg;base64,${base64Encode(_photo!)}',
          ),
        );
    if (!mounted) return;
    if (visit != null) {
      await showCheckinSuccess(context, visit);
      _reset();
      return;
    }
    final failure = ref.read(walkInSubmitProvider).error;
    if (failure is ServerFailure && failure.isBlacklisted) {
      _visitor.blacklist.value = BlacklistEntry(name: _visitor.name.text);
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_snackText(failure))));
  }

  static String _snackText(Object? failure) => switch (failure) {
    ServerFailure(statusCode: 422, errors: final e?) when e.isNotEmpty => 'Please fix the highlighted fields',
    final Failure f => f.message,
    _ => 'Something went wrong',
  };

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final submit = ref.watch(walkInSubmitProvider);
    final failure = submit.error is Failure ? submit.error as Failure : null;
    String? err(String f) => failure is ServerFailure ? failure.fieldError(f) : null;

    return Form(
      key: _formKey,
      child: ListView(
        key: ValueKey(_generation),
        padding: const EdgeInsets.all(16),
        children: [
          FormSection(
            title: 'Visitor Info',
            icon: Icons.person_outline,
            children: [
              VisitorFields(
                controller: _visitor,
                failure: failure,
                onPicked: (p) => setState(() {
                  _photo = null;
                  _existingPhotoUrl = p.photoUrl;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSection(
            title: 'Visit Info',
            icon: Icons.work_outline,
            children: [
              HostPicker(value: _hostId, errorText: err('host_employee_id'), onChanged: (v) => _hostId = v),
              VisitTypeDropdown(value: _type, onChanged: (v) => _type = v),
              _field(_purpose, 'Purpose', err('purpose')),
              _field(
                _persons,
                'Persons',
                err('persons_count'),
                keyboard: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) < 1 ? 'At least 1' : null,
              ),
              _field(_goods, 'Carrying Goods', err('carrying_goods'), hint: 'e.g. Laptop, documents, product samples'),
              _field(_vehicle, 'Vehicle No', err('vehicle_no')),
              _field(_remarks, 'Remarks', err('remarks'), maxLines: 2),
            ],
          ),
          const SizedBox(height: 12),
          FormSection(
            title: 'Photo',
            icon: Icons.photo_camera_outlined,
            children: [
              _PhotoPreview(bytes: _photo, url: _existingPhotoUrl),
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _takePhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera),
                      label: Text(_photo == null && _existingPhotoUrl == null ? 'Camera' : 'Retake'),
                    ),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _takePhoto(ImageSource.gallery),
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          FormSection(
            title: 'Check-in Method',
            icon: Icons.how_to_reg_outlined,
            children: [
              CheckinMethodSelector(value: _method, onChanged: (m) => setState(() => _method = m)),
              _field(
                _cardNo,
                _method == CheckinMethod.rfid ? 'Card No *' : 'Card No',
                err('card_no'),
                hint: 'Tap RFID card or type number',
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _hold,
                onChanged: (v) => setState(() => _hold = v ?? false),
                title: const Text('Wait for host approval (status: Pending)'),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (failure != null && (failure is! ServerFailure || failure.errors == null)) ...[
            FormErrorText(failure.message),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            onPressed: submit.isLoading ? null : _submit,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: submit.isLoading
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.login),
            label: const Text('Check-in'),
          ),
          TextButton(onPressed: submit.isLoading ? null : _reset, child: const Text('Reset')),
          const SizedBox(height: 24),
        ],
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
    FormFieldValidator<String>? validator,
  }) => TextFormField(
    controller: c,
    keyboardType: keyboard,
    maxLines: maxLines,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      border: const OutlineInputBorder(),
    ),
  );
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ImageProvider? image = bytes != null
        ? MemoryImage(bytes!)
        : url != null
        ? NetworkImage(url!)
        : null;
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          image: image == null ? null : DecorationImage(image: image, fit: BoxFit.cover),
        ),
        child: image == null
            ? Column(
                mainAxisAlignment: .center,
                children: [
                  Icon(Icons.person_outline, size: 48, color: scheme.outline),
                  Text('No photo', style: TextStyle(color: scheme.outline)),
                ],
              )
            : null,
      ),
    );
  }
}
