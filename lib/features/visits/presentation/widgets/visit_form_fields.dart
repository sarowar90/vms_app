import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/visit.dart';
import '../providers/visit_providers.dart';

/// Searchable host employee picker.
class HostPicker extends ConsumerWidget {
  const HostPicker({super.key, required this.value, required this.onChanged, this.errorText});

  final int? value;
  final ValueChanged<int?> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hosts = ref.watch(hostsProvider);
    return hosts.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.error_outline),
        title: Text('Could not load hosts: $e'),
        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(hostsProvider)),
      ),
      data: (list) => DropdownMenu<int>(
        // Rebuild when the value is reset from outside.
        key: ValueKey(value),
        initialSelection: value,
        expandedInsets: EdgeInsets.zero,
        enableFilter: true,
        requestFocusOnTap: true,
        menuHeight: 320,
        label: const Text('Host *'),
        leadingIcon: const Icon(Icons.person_search),
        errorText: errorText,
        dropdownMenuEntries: [for (final h in list) DropdownMenuEntry(value: h.id, label: h.label)],
        onSelected: onChanged,
      ),
    );
  }
}

class VisitTypeDropdown extends StatelessWidget {
  const VisitTypeDropdown({super.key, required this.value, required this.onChanged});

  final VisitType value;
  final ValueChanged<VisitType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<VisitType>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Visit Type *', border: OutlineInputBorder()),
      items: [for (final t in VisitType.values) DropdownMenuItem(value: t, child: Text(t.label))],
      onChanged: (v) => onChanged(v ?? VisitType.meeting),
    );
  }
}

/// Manual / QR / RFID choice.
class CheckinMethodSelector extends StatelessWidget {
  const CheckinMethodSelector({super.key, required this.value, required this.onChanged});

  final CheckinMethod value;
  final ValueChanged<CheckinMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CheckinMethod>(
      showSelectedIcon: false,
      segments: [
        for (final m in CheckinMethod.values)
          ButtonSegment(value: m, icon: Icon(m.icon), label: Text(m == CheckinMethod.rfid ? 'RFID' : m.label)),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Card section with an icon title, used to group form fields.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Error text from a failure that has no field to attach to.
class FormErrorText extends StatelessWidget {
  const FormErrorText(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(Icons.error_outline, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message!, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
