import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/error/failures.dart';
import '../../../visits/domain/entities/visit_entities.dart';
import '../../../visits/presentation/widgets/visit_form_fields.dart';
import '../../../visits/presentation/widgets/visitor_fields.dart';
import '../visitor_providers.dart';

/// Edit a visitor profile and photo (web: profile modal "Edit Profile" tab).
/// Pops with `true` when saved.
class VisitorEditPage extends ConsumerStatefulWidget {
  const VisitorEditPage({super.key, required this.visitor});

  final VisitorProfile visitor;

  static Future<bool> open(BuildContext context, VisitorProfile visitor) async =>
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => VisitorEditPage(visitor: visitor))) ??
      false;

  @override
  ConsumerState<VisitorEditPage> createState() => _VisitorEditPageState();
}

class _VisitorEditPageState extends ConsumerState<VisitorEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _fields = VisitorFieldsController();
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    _fields.fillFromProfile(widget.visitor, returning: false);
  }

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, maxWidth: 800, imageQuality: 75);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted) setState(() => _photo = bytes);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref
        .read(visitorMutationProvider.notifier)
        .save(
          widget.visitor.id,
          _fields.toInput(),
          photo: _photo == null ? null : 'data:image/jpeg;base64,${base64Encode(_photo!)}',
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    final failure = ref.read(visitorMutationProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(switch (failure) {
          ServerFailure(statusCode: 422, errors: final e?) when e.isNotEmpty => 'Please fix the highlighted fields',
          final Failure f => f.message,
          _ => 'Something went wrong',
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorMutationProvider);
    final failure = state.error is Failure ? state.error as Failure : null;
    final scheme = Theme.of(context).colorScheme;
    final url = widget.visitor.photoUrl;
    final ImageProvider? image = _photo != null ? MemoryImage(_photo!) : (url != null ? NetworkImage(url) : null);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FormSection(
              title: 'Photo',
              icon: Icons.photo_camera_outlined,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundImage: image,
                    child: Icon(Icons.person_outline, size: 48, color: scheme.outline),
                  ),
                ),
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera),
                        label: const Text('Camera'),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pick(ImageSource.gallery),
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
              title: 'Visitor Info',
              icon: Icons.person_outline,
              children: [VisitorFields(controller: _fields, failure: failure, searchEnabled: false)],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: state.isLoading ? null : _save,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: state.isLoading
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
