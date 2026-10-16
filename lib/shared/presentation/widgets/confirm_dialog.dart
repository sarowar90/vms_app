import 'package:flutter/material.dart';

/// Red "Delete" confirmation. Returns true when confirmed.
Future<bool> confirmDelete(BuildContext context, String message, {String okText = 'Delete'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error, size: 40),
      content: Text(message, textAlign: .center),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Confirm dialog with a remarks/reason box. Returns the text, or `null` if dismissed.
Future<String?> askRemarks(
  BuildContext context, {
  required String title,
  required String okText,
  required String inputLabel,
  required Color color,
}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 2,
        decoration: InputDecoration(labelText: inputLabel, border: const OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(okText),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}
