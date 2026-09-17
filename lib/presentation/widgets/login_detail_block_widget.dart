import 'package:flutter/material.dart';
import '../../data/models/item_field.dart';
import 'field_row_widget.dart';

/// Displays a username and password as one credential block in item details.
class LoginDetailBlock extends StatelessWidget {
  final String title;
  final ItemField username;
  final ItemField password;
  final Future<String?> Function() onRevealPassword;

  /// When `false`, the surrounding container is omitted so the block can live
  /// inside a larger grouped card (dividers are still drawn between fields).
  final bool bordered;

  const LoginDetailBlock({
    super.key,
    this.title = '',
    required this.username,
    required this.password,
    required this.onRevealPassword,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final content = Column(
      children: [
        if (title.isNotEmpty)
          Row(
            children: [
              Icon(Icons.label_rounded, size: 16, color: cs.tertiary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        if (title.isNotEmpty) Divider(height: 24, color: cs.outlineVariant),
        FieldRowWidget(field: username, includeContainer: false),
        Divider(height: 24, color: cs.outlineVariant),
        FieldRowWidget(
          field: password,
          includeContainer: false,
          onRevealRequested: onRevealPassword,
        ),
      ],
    );
    if (!bordered) return content;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: content,
    );
  }
}
