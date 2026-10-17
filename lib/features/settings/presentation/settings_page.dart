import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/usecase.dart';
import '../../../shared/domain/validators.dart';
import '../../../shared/presentation/widgets/async_value_view.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../shell/presentation/widgets/app_drawer.dart';
import '../data/settings_repository_impl.dart';
import '../domain/settings_repository.dart';

// ---------- Providers ----------

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepositoryImpl(SettingsRemoteDataSource(ref.watch(apiClientProvider))),
);

final companySettingsProvider = FutureProvider.autoDispose<CompanySettings>(
  (ref) async => (await GetSettings(ref.watch(settingsRepositoryProvider))(const NoParams())).getOrThrow(),
);

// ---------- Page ----------

/// Company Settings (web: `settings.php`).
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(companySettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const AppDrawer(),
      body: AsyncValueView(
        value: settings,
        onRetry: () => ref.invalidate(companySettingsProvider),
        data: (s) => _SettingsForm(key: ValueKey(s), initial: s),
      ),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({super.key, required this.initial});

  final CompanySettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial.companyName);
  late final _nameBn = TextEditingController(text: widget.initial.companyNameBn);
  late final _address = TextEditingController(text: widget.initial.address);
  late final _phone = TextEditingController(text: widget.initial.phone);
  late final _footer = TextEditingController(text: widget.initial.badgeFooter);
  late bool _requireApproval = widget.initial.requireApproval;
  late String _language = widget.initial.defaultLanguage;
  late String? _logoUrl = widget.initial.logoUrl;
  bool _saving = false;
  bool _uploading = false;
  Failure? _failure;

  @override
  void dispose() {
    for (final c in [_name, _nameBn, _address, _phone, _footer]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final result = await SaveSettings(ref.read(settingsRepositoryProvider))(
      CompanySettings(
        companyName: _name.text.trim(),
        companyNameBn: _opt(_nameBn),
        address: _opt(_address),
        phone: _opt(_phone),
        badgeFooter: _opt(_footer),
        requireApproval: _requireApproval,
        defaultLanguage: _language,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failure = result is Error<CompanySettings> ? result.failure : null;
    });
    if (result is Success) {
      // The company name shows in the menu header and on visitor passes.
      ref.invalidate(authProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Settings saved')));
    } else {
      messenger.showSnackBar(SnackBar(content: Text(_failure!.message)));
    }
  }

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    final result = await UploadLogo(ref.read(settingsRepositoryProvider))(
      'data:image/$mime;base64,${base64Encode(bytes)}',
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    switch (result) {
      case Success(:final value):
        // Bust the image cache: the server may reuse the URL.
        setState(() => _logoUrl = value == null ? null : '$value?t=${DateTime.now().millisecondsSinceEpoch}');
        messenger.showSnackBar(const SnackBar(content: Text('Logo updated')));
      case Error(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  String? _err(String field) => _failure is ServerFailure ? (_failure as ServerFailure).fieldError(field) : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    InputDecoration deco(String label, String field) =>
        InputDecoration(labelText: label, errorText: _err(field), border: const OutlineInputBorder());

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            icon: Icons.business,
            title: 'Company Settings',
            children: [
              if (widget.initial.companyCode != null)
                Text('Company code: ${widget.initial.companyCode}', style: theme.textTheme.bodySmall),
              TextFormField(
                controller: _name,
                maxLength: 150,
                decoration: deco('Company Name (English) *', 'company_name'),
                validator: (v) => Validators.required(v, 'Company name'),
              ),
              TextFormField(
                controller: _nameBn,
                maxLength: 150,
                decoration: deco('Company Name (বাংলা)', 'company_name_bn'),
              ),
              TextFormField(controller: _address, maxLength: 255, decoration: deco('Address', 'company_address')),
              TextFormField(
                controller: _phone,
                maxLength: 30,
                keyboardType: TextInputType.phone,
                decoration: deco('Phone', 'company_phone'),
              ),
              TextFormField(
                controller: _footer,
                maxLength: 255,
                decoration: deco('Visitor Pass Footer Text', 'badge_footer'),
              ),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: deco('Default Language', 'default_language'),
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
                ],
                onChanged: (v) => _language = v ?? 'en',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Require host approval for pre-registrations'),
                subtitle: const Text('When off, all pre-registrations are approved automatically.'),
                value: _requireApproval,
                onChanged: (v) => setState(() => _requireApproval = v),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                icon: _saving
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Submit'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            icon: Icons.image_outlined,
            title: 'Logo',
            children: [
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(12),
                child: _logoUrl == null
                    ? Icon(Icons.image_outlined, size: 48, color: theme.colorScheme.outline)
                    : Image.network(
                        _logoUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: theme.colorScheme.outline),
                      ),
              ),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickLogo,
                icon: _uploading
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload),
                label: const Text('Upload'),
              ),
              Text('PNG/JPG, max 2 MB', textAlign: .center, style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: .stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          ...children,
        ],
      ),
    ),
  );
}
