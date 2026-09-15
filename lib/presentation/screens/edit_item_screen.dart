import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../data/models/attachment.dart';
import '../../data/models/category.dart';
import '../../data/models/item.dart';
import '../../data/models/item_field.dart';
import '../../data/repositories/item_repository.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../widgets/attachment_grid_widget.dart';
import '../widgets/add_field_sheet.dart';
import '../widgets/field_editor_widget.dart';
import '../widgets/field_entry_dialog.dart';
import '../widgets/field_slot.dart';
import '../widgets/login_block_widget.dart';
import '../widgets/tag_chip_input_widget.dart';
import 'camera_screen.dart';

/// Edit Item — same layout as Add Item, pre-filled (spec §3.4).
class EditItemScreen extends StatefulWidget {
  final int itemId;

  const EditItemScreen({super.key, required this.itemId});

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _notesCtrl;

  List<Category> _categories = [];
  int? _selectedCategoryId;

  List<String> _tags = [];

  // Existing + newly added fields as editable slots (single fields and login
  // pairs, preserving sort_order).
  List<FieldSlot> _slots = [];
  int _slotKeyCounter = 0;

  final ScrollController _scrollController = ScrollController();

  // Field IDs removed in this session — their reminders get cancelled.
  final List<int> _deletedFieldIds = [];

  // Existing attachments still kept + newly added local paths.
  List<Attachment> _attachments = [];
  final List<String> _newAttachmentPaths = [];
  final List<int> _deletedAttachmentIds = [];

  Item? _item;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _loadItem();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final repo = context.read<ItemRepository>();
      final cats = await repo.getAllCategories();
      final details = await repo.getItemWithDetails(widget.itemId);
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _isLoading = false;
          _loadError = 'Item not found';
        });
        return;
      }
      setState(() {
        _item = details.item;
        _categories = cats;
        _selectedCategoryId = details.item.categoryId;
        _tags = List<String>.from(details.item.tags);
        _titleCtrl.text = details.item.title;
        _notesCtrl.text = details.item.notes ?? '';
        _attachments = List<Attachment>.from(details.attachments);
        // Pre-fill fields preserving sort order. PASSWORD values are never
        // loaded into the editor — an empty value means "keep the stored secret".
        // Consecutive Username + Password fields are grouped back into a single
        // login entity for editing.
        final passwordCleared = details.fields
            .map(
              (f) =>
                  f.fieldType == FieldType.password ? f.copyWith(value: '') : f,
            )
            .toList();
        _slots = FieldSlot.buildFromFields(
          passwordCleared,
          nextKey: _nextSlotKey,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load item: $e';
      });
    }
  }

  Future<void> _onSave() async {
    final item = _item;
    if (item == null) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final updated = item.copyWith(
      title: _titleCtrl.text.trim(),
      categoryId: _selectedCategoryId,
      tags: _tags,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      updatedAt: DateTime.now(),
    );

    final completion = Completer<void>();
    context.read<ItemBloc>().add(
      UpdateItem(
        item: updated,
        fields: _slots.expand((s) => s.fields).toList(),
        deletedFieldIds: _deletedFieldIds,
        newAttachmentPaths: _newAttachmentPaths,
        deletedAttachmentIds: _deletedAttachmentIds,
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
        ).showSnackBar(const SnackBar(content: Text('Failed to save changes')));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Field management
  // ---------------------------------------------------------------------------

  Future<void> _openAddFieldSheet() async {
    final choice = await showAddFieldSheet(context);
    if (choice == null || !mounted) return;

    if (choice == AddFieldChoice.login) {
      final pair = await showLoginEntryDialog(context, itemId: widget.itemId);
      if (pair == null || !mounted) return;
      _addLoginTemplate(pair);
    } else {
      final type = _fieldTypeFor(choice);
      final field = await showFieldEntryDialog(
        context,
        field: ItemField(
          itemId: widget.itemId,
          label: '',
          fieldType: type,
          value: '',
        ),
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
    setState(() => _slots.add(FieldSlot.single(_nextSlotKey(), field)));
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
    setState(() {
      final removed = _slots.removeAt(index);
      for (final id in removed.existingFieldIds) {
        _deletedFieldIds.add(id);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Attachment management
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto() async {
    final path = await ImagePickerHelper.pick(context, ImageSource.gallery);
    if (path != null) setState(() => _newAttachmentPaths.add(path));
  }

  Future<void> _takePhoto() async {
    final photo = await showCameraScreen(context);
    if (photo != null) setState(() => _newAttachmentPaths.add(photo.path));
  }

  Future<void> _pickPdf() async {
    ImagePickerHelper.isPickerActive = true;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() => _newAttachmentPaths.add(result.files.single.path!));
      }
    } finally {
      ImagePickerHelper.endPickerSession();
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      final removed = _attachments.removeAt(index);
      if (removed.id != null) _deletedAttachmentIds.add(removed.id!);
    });
  }

  void _removeNewAttachment(int index) {
    setState(() => _newAttachmentPaths.removeAt(index));
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
        title: const Text('Edit Item'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _onSave,
            child: const Text('Save'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(cs),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadItem, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
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

          // 4. Attachments (existing + new)
          _SectionLabel('Attachments'),
          const SizedBox(height: 8),
          if (_attachments.isNotEmpty) ...[
            AttachmentGrid(
              attachments: _attachments,
              showDelete: true,
              onDelete: (a) {
                final idx = _attachments.indexWhere((x) => x.id == a.id);
                if (idx >= 0) _removeAttachment(idx);
              },
            ),
            const SizedBox(height: 12),
          ],
          if (_newAttachmentPaths.isNotEmpty) ...[
            _buildNewAttachmentsList(cs),
            const SizedBox(height: 12),
          ],
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

          // 5. Fields (pre-filled, reorderable)
          _SectionLabel('Fields'),
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

          // 6. Notes
          _SectionLabel('Notes'),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            maxLines: null,
            minLines: 3,
            decoration: const InputDecoration(hintText: 'Any extra details...'),
          ),
        ],
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

  Widget _buildNewAttachmentsList(ColorScheme cs) {
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _newAttachmentPaths.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final path = _newAttachmentPaths[index];
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
                  onTap: () => _removeNewAttachment(index),
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
