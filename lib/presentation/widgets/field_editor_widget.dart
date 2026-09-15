import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/item_field.dart';

/// Inline editor row shown inside Add/Edit Item screen.
/// Consists of:
///   - Drag handle (for reordering)
///   - Label text field
///   - Type segmented control (Text / Date / Password)
///   - Value input (changes based on type)
///   - For Date: reminder toggle + lead-time selector
///   - Delete button (X)
class FieldEditorWidget extends StatefulWidget {
  final ItemField field;
  final ValueChanged<ItemField> onChanged;
  final VoidCallback onDelete;

  /// Hide the drag handle. Used for the fixed quick-expiry field.
  final bool showDragHandle;

  /// Hide the label TextField; shows the field label as static text instead.
  final bool showLabelEditor;

  /// Hide the Text/Date/Password type selector. Used when the field type is
  /// fixed (e.g. the quick-expiry date field).
  final bool showTypeSelector;

  /// Render without the card surface when embedded in a dialog.
  final bool showContainer;

  /// Hide the inline delete button when the dialog actions provide dismissal.
  final bool showDeleteButton;

  /// Separate label, value, and date reminder sections when shown in a dialog.
  final bool showSectionDividers;

  /// Give popup text inputs a larger, easier-to-tap typing area.
  final bool expandedInputs;

  const FieldEditorWidget({
    super.key,
    required this.field,
    required this.onChanged,
    required this.onDelete,
    this.showDragHandle = true,
    this.showLabelEditor = true,
    this.showTypeSelector = true,
    this.showContainer = true,
    this.showDeleteButton = true,
    this.showSectionDividers = false,
    this.expandedInputs = false,
  });

  @override
  State<FieldEditorWidget> createState() => _FieldEditorWidgetState();
}

class _FieldEditorWidgetState extends State<FieldEditorWidget> {
  late TextEditingController _labelCtrl;
  late TextEditingController _valueCtrl;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _valueCtrl = TextEditingController(
      text: widget.field.fieldType == FieldType.password
          ? ''
          : widget.field.value,
    );
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  void _emit(ItemField updated) => widget.onChanged(updated);

  void _onLabelChanged(String val) => _emit(widget.field.copyWith(label: val));

  void _onValueChanged(String val) => _emit(widget.field.copyWith(value: val));

  void _onTypeChanged(FieldType type) {
    _valueCtrl.clear();
    _emit(
      widget.field.copyWith(fieldType: type, value: '', reminderEnabled: false),
    );
  }

  Future<void> _pickDate() async {
    final initial = widget.field.parsedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final iso = DateFormat(AppConstants.dateFormatISO).format(picked);
      _valueCtrl.text = iso;
      _emit(widget.field.copyWith(value: iso));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: widget.showContainer
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      padding: widget.showContainer
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
          : EdgeInsets.zero,
      decoration: widget.showContainer
          ? BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.showDragHandle) ...[
                Icon(
                  Icons.drag_handle_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: widget.showLabelEditor
                    ? TextField(
                        controller: _labelCtrl,
                        decoration: InputDecoration(
                          hintText: 'Field label (e.g. PAN Number)',
                          isDense: !widget.expandedInputs,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          fillColor: Colors.transparent,
                          filled: false,
                          contentPadding: widget.expandedInputs
                              ? const EdgeInsets.symmetric(vertical: 10)
                              : EdgeInsets.zero,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        onChanged: _onLabelChanged,
                      )
                    : Text(
                        widget.field.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
              ),
              if (widget.showDeleteButton)
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(Icons.close_rounded, color: cs.error, size: 20),
                ),
            ],
          ),
          if (widget.showSectionDividers) ...[
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 16),
          ] else
            const SizedBox(height: 12),
          // Type selector
          if (widget.showTypeSelector) ...[
            _TypeSelector(
              selected: widget.field.fieldType,
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 12),
          ],
          // Value input
          _buildValueInput(cs),
          // DATE: reminder controls
          if (widget.field.fieldType == FieldType.date) ...[
            if (widget.showSectionDividers) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: cs.outlineVariant),
              const SizedBox(height: 16),
            ] else
              const SizedBox(height: 12),
            _ReminderControls(
              enabled: widget.field.reminderEnabled,
              leadDays: widget.field.reminderLeadDays,
              onEnabledChanged: (v) =>
                  _emit(widget.field.copyWith(reminderEnabled: v)),
              onLeadDaysChanged: (d) =>
                  _emit(widget.field.copyWith(reminderLeadDays: d)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildValueInput(ColorScheme cs) {
    switch (widget.field.fieldType) {
      case FieldType.text:
        return TextField(
          controller: _valueCtrl,
          decoration: InputDecoration(
            hintText: 'Value',
            isDense: !widget.expandedInputs,
            contentPadding: widget.expandedInputs
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                : null,
          ),
          onChanged: _onValueChanged,
        );
      case FieldType.date:
        return GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 10),
                Text(
                  widget.field.value.isEmpty
                      ? 'Select date'
                      : _formatDate(widget.field.value),
                  style: TextStyle(
                    color: widget.field.value.isEmpty
                        ? cs.onSurfaceVariant
                        : cs.onSurface,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        );
      case FieldType.password:
        return TextField(
          controller: _valueCtrl,
          obscureText: !_passwordVisible,
          decoration: InputDecoration(
            hintText: 'Password / secret value',
            isDense: !widget.expandedInputs,
            contentPadding: widget.expandedInputs
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                : null,
            suffixIcon: IconButton(
              icon: Icon(
                _passwordVisible
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
          ),
          onChanged: _onValueChanged,
        );
    }
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat(AppConstants.dateFormatDisplay).format(d);
    } catch (_) {
      return iso;
    }
  }
}

class _TypeSelector extends StatelessWidget {
  final FieldType selected;
  final ValueChanged<FieldType> onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: FieldType.values.map((type) {
        final isSelected = type == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  type.displayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReminderControls extends StatelessWidget {
  final bool enabled;
  final int? leadDays;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int?> onLeadDaysChanged;

  const _ReminderControls({
    required this.enabled,
    required this.leadDays,
    required this.onEnabledChanged,
    required this.onLeadDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.notifications_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remind me before this date',
                style: TextStyle(fontSize: 13, color: cs.onSurface),
              ),
            ),
            const SizedBox(width: 8),
            Switch(value: enabled, onChanged: onEnabledChanged),
          ],
        ),
        if (enabled) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [...AppConstants.leadTimeOptions, null].map((days) {
              final isSelected = leadDays == days;
              final label = days == null ? 'Custom' : '${days}d';
              return ChoiceChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) {
                  if (days == null) {
                    _showCustomDialog(context);
                  } else {
                    onLeadDaysChanged(days);
                  }
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _showCustomDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: leadDays?.toString() ?? '');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom lead days'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Days before date'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && result > 0) onLeadDaysChanged(result);
  }
}
