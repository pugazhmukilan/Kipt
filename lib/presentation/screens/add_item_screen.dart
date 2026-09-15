import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/utils/preferences_helper.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/models/item_field.dart';
import '../../data/repositories/item_repository.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../widgets/add_field_sheet.dart';
import '../widgets/field_editor_widget.dart';
import '../widgets/field_entry_dialog.dart';
import '../widgets/field_slot.dart';
import '../widgets/login_block_widget.dart';
import '../widgets/tag_chip_input_widget.dart';
import 'camera_screen.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;

  List<String> _tags = [];

  // Toggle for quick expiry
  bool _quickExpiryEnabled = false;
  ItemField? _quickExpiryField;

  // Additional fields (single fields and login pairs as editable slots).
  final List<FieldSlot> _slots = [];
  int _slotKeyCounter = 0;

  final ScrollController _scrollController = ScrollController();

  // Attachments (local paths)
  final List<String> _attachmentPaths = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await context.read<ItemRepository>().getAllCategories();
    if (mounted) setState(() => _categories = cats);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final item = Item(
      title: _titleCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      tags: _tags,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final allFields = <ItemField>[];
    if (_quickExpiryEnabled && _quickExpiryField != null) {
      allFields.add(_quickExpiryField!);
    }
    for (final slot in _slots) {
      allFields.addAll(slot.fields);
    }

    final completion = Completer<void>();
    context.read<ItemBloc>().add(
      CreateItem(
        item: item,
        fields: allFields,
        attachmentPaths: _attachmentPaths,
        completion: completion,
      ),
    );

    try {
      await completion.future;
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to save item')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Field management
  // ---------------------------------------------------------------------------

  void _toggleQuickExpiry(bool enabled) {
    setState(() {
      _quickExpiryEnabled = enabled;
      if (enabled && _quickExpiryField == null) {
        _quickExpiryField = ItemField(
          itemId: 0, // Assigned on save
          label: 'Expiry Date',
          fieldType: FieldType.date,
          value: '',
          reminderEnabled: true,
          reminderLeadDays: PreferencesHelper.getDefaultLeadDays(),
        );
      }
    });
  }

  Future<void> _openAddFieldSheet() async {
    final choice = await showAddFieldSheet(context);
    if (choice == null || !mounted) return;

    if (choice == AddFieldChoice.login) {
      final pair = await showLoginEntryDialog(context, itemId: 0);
      if (pair == null || !mounted) return;
      _addLoginTemplate(pair);
    } else {
      final type = _fieldTypeFor(choice);
      final field = await showFieldEntryDialog(
        context,
        field: ItemField(itemId: 0, label: '', fieldType: type, value: ''),
      );
      if (field == null || !mounted) return;
      _addField(field);
    }

    _scrollToBottom();
  }

  FieldType _fieldTypeFor(AddFieldChoice choice) {
    switch (choice) {
      case AddFieldChoice.login:
        return FieldType.text;
      case AddFieldChoice.text:
        return FieldType.text;
      case AddFieldChoice.password:
        return FieldType.password;
      case AddFieldChoice.date:
        return FieldType.date;
    }
  }

  void _addField(ItemField field) {
    _slots.add(FieldSlot.single(_nextSlotKey(), field));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  void _addLoginTemplate(LoginFieldPair pair) {
    setState(() => _slots.add(FieldSlot.login(_nextSlotKey(), pair)));
  }

  Object _nextSlotKey() => 'slot${_slotKeyCounter++}';

  void _updateSlot(int index, ItemField updated) {
    setState(() {
      final slot = _slots[index];
      if (slot.isLogin) return;
      slot.single = updated;
    });
  }

  void _removeSlot(int index) {
    setState(() => _slots.removeAt(index));
  }

  // ---------------------------------------------------------------------------
  // Attachment management
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto() async {
    final path = await ImagePickerHelper.pick(context, ImageSource.gallery);
    if (path != null) setState(() => _attachmentPaths.add(path));
  }

  Future<void> _takePhoto() async {
    final photo = await showCameraScreen(context);
    if (photo != null) setState(() => _attachmentPaths.add(photo.path));
  }

  Future<void> _pickPdf() async {
    ImagePickerHelper.isPickerActive = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _attachmentPaths.add(result.files.single.path!));
      }
    } finally {
      ImagePickerHelper.endPickerSession();
    }
  }

  void _removeAttachment(int index) {
    setState(() => _attachmentPaths.removeAt(index));
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Add Item'),
        actions: [
          TextButton(onPressed: _onSave, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Title
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Item Title',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(height: 24),

            // 2. Category
            _SectionLabel('Category'),
            const SizedBox(height: 8),
            _buildCategorySelector(cs),
            const SizedBox(height: 24),

            // 3. Tags
            _SectionLabel('Tags'),
            const SizedBox(height: 8),
            TagChipInput(
              tags: _tags,
              onChanged: (tags) => setState(() => _tags = tags),
            ),
            const SizedBox(height: 24),

            // 4. Quick Expiry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.event_busy_rounded, color: cs.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Track an expiry date for this item?',
                          style: TextStyle(fontSize: 15, color: cs.onSurface),
                        ),
                      ),
                      Switch(
                        value: _quickExpiryEnabled,
                        onChanged: _toggleQuickExpiry,
                      ),
                    ],
                  ),
                  if (_quickExpiryEnabled && _quickExpiryField != null) ...[
                    const Divider(height: 24),
                    FieldEditorWidget(
                      field: _quickExpiryField!,
                      onChanged: (f) => setState(() => _quickExpiryField = f),
                      onDelete: () => _toggleQuickExpiry(false),
                      showDragHandle: false,
                      showLabelEditor: false,
                      showTypeSelector: false,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 5. Attachments
            _SectionLabel('Attachments'),
            const SizedBox(height: 8),
            _buildAttachmentsList(cs),
            const SizedBox(height: 12),
            Row(
              children: [
                _AttachmentAction(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: _takePhoto,
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _AttachmentAction(
                  icon: Icons.photo_library_rounded,
                  label: 'Photo',
                  onTap: _pickPhoto,
                  cs: cs,
                ),
                const SizedBox(width: 8),
                _AttachmentAction(
                  icon: Icons.picture_as_pdf_rounded,
                  label: 'PDF',
                  onTap: _pickPdf,
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 6. Additional Fields
            _SectionLabel('Additional Fields'),
            const SizedBox(height: 8),
            Row(
              children: [
                _AttachmentAction(
                  icon: Icons.add_rounded,
                  label: 'Add Field',
                  onTap: _openAddFieldSheet,
                  cs: cs,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_slots.isEmpty)
              Text(
                'Add custom fields like passwords, IDs, or dates.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: true,
                itemCount: _slots.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final slot = _slots.removeAt(oldIndex);
                    _slots.insert(newIndex, slot);
                  });
                },
                itemBuilder: (context, index) {
                  final slot = _slots[index];
                  if (slot.isLogin) {
                    return LoginBlockWidget(
                      key: ValueKey(slot.key),
                      titleValue: slot.login!.title,
                      usernameValue: slot.login!.username.value,
                      passwordValue: slot.login!.password.value,
                      onTitleChanged: (v) => setState(() {
                        slot.login!.title = v;
                      }),
                      onUsernameChanged: (v) => setState(() {
                        slot.login!.username = slot.login!.username.copyWith(
                          value: v,
                        );
                      }),
                      onPasswordChanged: (v) => setState(() {
                        slot.login!.password = slot.login!.password.copyWith(
                          value: v,
                        );
                      }),
                      onDelete: () => _removeSlot(index),
                    );
                  }
                  return FieldEditorWidget(
                    key: ValueKey(slot.key),
                    field: slot.single!,
                    onChanged: (f) => _updateSlot(index, f),
                    onDelete: () => _removeSlot(index),
                  );
                },
              ),
            const SizedBox(height: 24),

            // 7. Notes
            _SectionLabel('Notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                hintText: 'Any extra details...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector(ColorScheme cs) {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return DropdownButtonFormField<int>(
      initialValue: _selectedCategoryId,
      hint: const Text('Select category'),
      items: _categories.map((c) {
        return DropdownMenuItem<int>(value: c.id, child: Text(c.name));
      }).toList(),
      onChanged: (val) => setState(() => _selectedCategoryId = val),
      decoration: InputDecoration(
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildAttachmentsList(ColorScheme cs) {
    if (_attachmentPaths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachmentPaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = _attachmentPaths[index];
          final isPdf = path.toLowerCase().endsWith('.pdf');
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 72,
                  height: 72,
                  color: isPdf ? cs.errorContainer : cs.surfaceContainerHigh,
                  child: isPdf
                      ? Icon(Icons.picture_as_pdf, color: cs.onErrorContainer)
                      : Image.file(File(path), fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeAttachment(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AttachmentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _AttachmentAction({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: cs.onSurfaceVariant),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
