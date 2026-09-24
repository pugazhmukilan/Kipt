import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/item_field.dart';
import 'status_badge_widget.dart';

/// Displays a single ItemField in the Item Detail view.
/// TEXT: label + value + copy icon
/// DATE: label + formatted date + countdown + reminder bell
/// PASSWORD: label + masked dots + reveal (biometric each time) + copy (45s clear)
class FieldRowWidget extends StatefulWidget {
  final ItemField field;
  final bool includeContainer;
  final String? decryptedValue; // Pre-resolved for PASSWORD fields
  final Future<String?> Function()? onRevealRequested;
  final VoidCallback? onCopyPassword;

  const FieldRowWidget({
    super.key,
    required this.field,
    this.includeContainer = true,
    this.decryptedValue,
    this.onRevealRequested,
    this.onCopyPassword,
  });

  @override
  State<FieldRowWidget> createState() => _FieldRowWidgetState();
}

class _FieldRowWidgetState extends State<FieldRowWidget> {
  bool _isRevealed = false;
  String? _revealedValue;
  bool _isRevealLoading = false;

  @override
  Widget build(BuildContext context) {
    switch (widget.field.fieldType) {
      case FieldType.text:
        return _TextRow(
          field: widget.field,
          includeContainer: widget.includeContainer,
        );
      case FieldType.date:
        return _DateRow(
          field: widget.field,
          includeContainer: widget.includeContainer,
        );
      case FieldType.password:
        return _PasswordRow(
          field: widget.field,
          isRevealed: _isRevealed,
          revealedValue: _revealedValue,
          isLoading: _isRevealLoading,
          onReveal: _handleReveal,
          onMask: _handleMask,
          onCopy: _handleCopy,
          includeContainer: widget.includeContainer,
        );
    }
  }

  Future<void> _handleReveal() async {
    if (_isRevealLoading) return;
    setState(() => _isRevealLoading = true);
    try {
      final val = await widget.onRevealRequested?.call();
      if (!mounted) return;
      if (val != null) {
        setState(() {
          _isRevealed = true;
          _revealedValue = val;
        });
        // Auto-remask after 20s
        Future.delayed(
          const Duration(seconds: AppConstants.passwordRemaskSeconds),
          () {
            if (mounted) _handleMask();
          },
        );
      }
    } finally {
      if (mounted) setState(() => _isRevealLoading = false);
    }
  }

  void _handleMask() {
    if (mounted) {
      setState(() {
        _isRevealed = false;
        _revealedValue = null;
      });
    }
  }

  void _handleCopy() {
    final val = _revealedValue ?? widget.decryptedValue;
    if (val == null) return;
    Clipboard.setData(ClipboardData(text: val));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied — clipboard clears in 45s')),
    );
    // Auto-clear clipboard after 45 seconds
    Future.delayed(
      const Duration(seconds: AppConstants.clipboardClearSeconds),
      () => Clipboard.setData(const ClipboardData(text: '')),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _TextRow extends StatelessWidget {
  final ItemField field;
  final bool includeContainer;
  const _TextRow({required this.field, required this.includeContainer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FieldLabel(label: field.label),
              const SizedBox(height: 8),
              Text(
                field.value.isEmpty ? '—' : field.value,
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (field.value.isNotEmpty) _CopyButton(textToCopy: field.value),
      ],
    );
    return includeContainer ? _FieldContainer(child: content) : content;
  }
}

class _DateRow extends StatelessWidget {
  final ItemField field;
  final bool includeContainer;
  const _DateRow({required this.field, required this.includeContainer});

  String _formatDate(DateTime d) =>
      DateFormat(AppConstants.dateFormatDisplay).format(d);

  String _relativeLabel(int days) {
    if (days == 0) return 'Today';
    if (days < 0) return '${days.abs()} day${days.abs() == 1 ? '' : 's'} ago';
    return 'In $days day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = field.parsedDate;
    final days = field.daysRemaining;

    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FieldLabel(label: field.label),
                  if (field.reminderEnabled) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 14,
                      color: cs.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (date != null) ...[
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (days != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _relativeLabel(days),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (field.reminderEnabled)
                        StatusBadge(status: field.status, compact: true),
                    ],
                  ),
                ],
              ] else
                Text(
                  'No date set',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
    return includeContainer ? _FieldContainer(child: content) : content;
  }
}

class _PasswordRow extends StatelessWidget {
  final ItemField field;
  final bool isRevealed;
  final String? revealedValue;
  final bool isLoading;
  final VoidCallback onReveal;
  final VoidCallback onMask;
  final VoidCallback onCopy;
  final bool includeContainer;

  const _PasswordRow({
    required this.field,
    required this.isRevealed,
    required this.revealedValue,
    required this.isLoading,
    required this.onReveal,
    required this.onMask,
    required this.onCopy,
    required this.includeContainer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _FieldLabel(label: field.label),
                  const SizedBox(width: 6),
                  Icon(Icons.lock_rounded, size: 13, color: cs.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isRevealed && revealedValue != null
                    ? revealedValue!
                    : '••••••••••',
                style: TextStyle(
                  fontSize: 16,
                  letterSpacing: isRevealed ? 0 : 3,
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (isLoading)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          IconButton(
            icon: Icon(
              isRevealed
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
            ),
            color: cs.primary,
            tooltip: isRevealed ? 'Hide' : 'Reveal',
            onPressed: isRevealed ? onMask : onReveal,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            color: cs.onSurfaceVariant,
            tooltip: 'Copy (clears in 45s)',
            onPressed: isRevealed ? onCopy : onReveal,
          ),
        ],
      ],
    );
    return includeContainer ? _FieldContainer(child: content) : content;
  }
}

// ---------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------

class _FieldContainer extends StatelessWidget {
  final Widget child;
  const _FieldContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  final String textToCopy;
  const _CopyButton({required this.textToCopy});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.copy_rounded, size: 18),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      tooltip: 'Copy',
      onPressed: () {
        Clipboard.setData(ClipboardData(text: textToCopy));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
      },
    );
  }
}
