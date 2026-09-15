import 'package:flutter/material.dart';

/// Single card representing a Username + Password login credential group.
/// Rendered as ONE entity in the Add/Edit Item fields list (with its own
/// drag handle + delete), instead of two separate generic field editors.
class LoginBlockWidget extends StatefulWidget {
  final String titleValue;
  final String usernameValue;
  final String passwordValue;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback onDelete;
  final bool showContainer;
  final bool showHeader;
  final bool showFieldContainers;
  final bool showSectionDivider;
  final bool expandedInputs;

  const LoginBlockWidget({
    super.key,
    this.titleValue = '',
    required this.usernameValue,
    required this.passwordValue,
    this.onTitleChanged = _noop,
    required this.onUsernameChanged,
    required this.onPasswordChanged,
    required this.onDelete,
    this.showContainer = true,
    this.showHeader = true,
    this.showFieldContainers = true,
    this.showSectionDivider = false,
    this.expandedInputs = false,
  });

  static void _noop(String _) {}

  @override
  State<LoginBlockWidget> createState() => _LoginBlockWidgetState();
}

class _LoginBlockWidgetState extends State<LoginBlockWidget> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.titleValue);
    _usernameCtrl = TextEditingController(text: widget.usernameValue);
    _passwordCtrl = TextEditingController(text: widget.passwordValue);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: widget.showContainer
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      padding: widget.showContainer
          ? const EdgeInsets.all(12)
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
          if (widget.showHeader)
            Row(
              children: [
                Icon(
                  Icons.drag_handle_rounded,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LOGIN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: cs.onPrimaryContainer,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onDelete,
                  child: Icon(Icons.close_rounded, color: cs.error, size: 20),
                ),
              ],
            ),
          if (widget.showHeader) const SizedBox(height: 12),
          _CredentialField(
            title: 'Title',
            icon: Icons.label_rounded,
            cs: cs,
            showContainer: widget.showFieldContainers,
            child: TextField(
              controller: _titleCtrl,
              onChanged: widget.onTitleChanged,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. ICICI Bank credentials',
                isDense: !widget.expandedInputs,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: widget.expandedInputs
                    ? const EdgeInsets.symmetric(vertical: 12)
                    : EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.showSectionDivider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: cs.outlineVariant),
            )
          else
            const SizedBox(height: 10),
          _CredentialField(
            title: 'Username',
            icon: Icons.person_rounded,
            cs: cs,
            showContainer: widget.showFieldContainers,
            child: TextField(
              controller: _usernameCtrl,
              onChanged: widget.onUsernameChanged,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Username or email',
                isDense: !widget.expandedInputs,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: widget.expandedInputs
                    ? const EdgeInsets.symmetric(vertical: 12)
                    : EdgeInsets.zero,
              ),
            ),
          ),
          if (widget.showSectionDivider)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: cs.outlineVariant),
            )
          else
            const SizedBox(height: 10),
          _CredentialField(
            title: 'Password',
            icon: Icons.lock_rounded,
            cs: cs,
            showContainer: widget.showFieldContainers,
            child: TextField(
              controller: _passwordCtrl,
              obscureText: !_passwordVisible,
              onChanged: widget.onPasswordChanged,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Password',
                isDense: !widget.expandedInputs,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: widget.expandedInputs
                    ? const EdgeInsets.symmetric(vertical: 12)
                    : EdgeInsets.zero,
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
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialField extends StatelessWidget {
  final String title;
  final IconData icon;
  final ColorScheme cs;
  final Widget child;
  final bool showContainer;

  const _CredentialField({
    required this.title,
    required this.icon,
    required this.cs,
    required this.child,
    required this.showContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: showContainer
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : EdgeInsets.zero,
      decoration: showContainer
          ? BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
