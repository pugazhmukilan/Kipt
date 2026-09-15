import 'package:flutter/material.dart';
import '../../data/models/item_field.dart';
import 'field_editor_widget.dart';
import 'field_slot.dart';
import 'login_block_widget.dart';

Future<ItemField?> showFieldEntryDialog(
  BuildContext context, {
  required ItemField field,
}) {
  return showDialog<ItemField>(
    context: context,
    builder: (context) => _FieldEntryDialog(field: field),
  );
}

Future<LoginFieldPair?> showLoginEntryDialog(
  BuildContext context, {
  required int itemId,
}) {
  return showDialog<LoginFieldPair>(
    context: context,
    builder: (context) => _LoginEntryDialog(itemId: itemId),
  );
}

class _FieldEntryDialog extends StatefulWidget {
  final ItemField field;

  const _FieldEntryDialog({required this.field});

  @override
  State<_FieldEntryDialog> createState() => _FieldEntryDialogState();
}

class _FieldEntryDialogState extends State<_FieldEntryDialog> {
  late ItemField _field;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 680),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      contentPadding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Icon(_iconFor(_field.fieldType), color: cs.primary),
          const SizedBox(width: 10),
          Text('Add ${_field.fieldType.displayLabel} field'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: FieldEditorWidget(
            field: _field,
            onChanged: (field) => setState(() => _field = field),
            onDelete: () => Navigator.of(context).pop(),
            showDragHandle: false,
            showTypeSelector: false,
            showContainer: false,
            showDeleteButton: false,
            showSectionDividers: true,
            expandedInputs: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(_field),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Add field'),
        ),
      ],
    );
  }

  IconData _iconFor(FieldType type) {
    switch (type) {
      case FieldType.text:
        return Icons.text_fields_rounded;
      case FieldType.password:
        return Icons.key_rounded;
      case FieldType.date:
        return Icons.event_rounded;
    }
  }
}

class _LoginEntryDialog extends StatefulWidget {
  final int itemId;

  const _LoginEntryDialog({required this.itemId});

  @override
  State<_LoginEntryDialog> createState() => _LoginEntryDialogState();
}

class _LoginEntryDialogState extends State<_LoginEntryDialog> {
  late String _title;
  late String _username;
  late String _password;

  @override
  void initState() {
    super.initState();
    _title = '';
    _username = '';
    _password = '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      constraints: const BoxConstraints(maxWidth: 680),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
      contentPadding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      title: Row(
        children: [
          Icon(Icons.lock_person_rounded, color: cs.tertiary),
          const SizedBox(width: 10),
          const Text('Add login'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: LoginBlockWidget(
            titleValue: _title,
            usernameValue: _username,
            passwordValue: _password,
            onTitleChanged: (value) => _title = value,
            onUsernameChanged: (value) => _username = value,
            onPasswordChanged: (value) => _password = value,
            onDelete: () => Navigator.of(context).pop(),
            showContainer: false,
            showHeader: false,
            showFieldContainers: false,
            showSectionDivider: true,
            expandedInputs: true,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(
            LoginFieldPair(
              title: _title,
              username: ItemField(
                itemId: widget.itemId,
                label: 'Username',
                fieldType: FieldType.text,
                value: _username,
              ),
              password: ItemField(
                itemId: widget.itemId,
                label: 'Password',
                fieldType: FieldType.password,
                value: _password,
              ),
            ),
          ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Add login'),
        ),
      ],
    );
  }
}
