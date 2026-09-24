import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_constants.dart';
import '../../core/spacing.dart';
import '../../core/utils/camera_aspect_ratio.dart';
import '../../data/models/attachment.dart';
import '../../data/models/item_field.dart';
import '../../data/models/item_with_details.dart';
import '../../data/repositories/auth_service.dart';
import '../../data/repositories/item_pdf_service.dart';
import '../../data/repositories/item_repository.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../bloc/item/item_state.dart';
import '../widgets/attachment_grid_widget.dart';
import '../widgets/field_row_widget.dart';
import '../widgets/login_detail_block_widget.dart';
import 'edit_item_screen.dart';
import 'item_preview_screen.dart';

class ItemDetailScreen extends StatefulWidget {
  final int itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  bool _fieldsCollapsed = true;
  final PageController _photoController = PageController();
  int _currentPhotoIndex = 0;

  /// Guards against dispatching a `LoadItemDetails` reload more than once from
  /// the same list-carrying state, which would otherwise ping-pong forever if
  /// the item can no longer be loaded.
  bool _awaitingReload = false;

  @override
  void initState() {
    super.initState();
    context.read<ItemBloc>().add(LoadItemDetails(widget.itemId));
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  /// Re-requests this item's details whenever the shared bloc state does not
  /// yet contain the details for this item.
  ///
  /// Returns `true` when the caller should keep showing a loading spinner and
  /// `false` when a terminal fallback (error or "item not found") is shown.
  ///
  /// This covers list-level states too (`ItemsLoaded`, `ItemsFiltered`,
  /// `ItemSearchResults`, `ItemOperationSuccess`): after saving an edit the
  /// detail screen pops back while the list screen (below it in the stack)
  /// may have fired a `LoadItems` that emitted `ItemsLoaded`. If we only
  /// re-fetched on `ItemOperationSuccess`, the detail page would be stuck on
  /// a loading spinner forever because `ItemsLoaded` never triggers a reload.
  ///
  /// The one state we never re-request from is a loaded list that no longer
  /// contains this item — that means it was deleted, so we show the
  /// "item not found" placeholder instead of looping forever.
  bool _ensureItemDetails(ItemState state) {
    if (state is ItemLoading) {
      _awaitingReload = false;
      return true;
    }
    if (state is ItemError) {
      _awaitingReload = false;
      return false;
    }
    if (state is ItemDetailsLoaded && state.item.item.id == widget.itemId) {
      _awaitingReload = false;
      return false;
    }

    // Any list-carrying state lets us decide whether this item still exists.
    final list = _itemsListFrom(state);
    if (list != null && !list.any((e) => e.item.id == widget.itemId)) {
      _awaitingReload = false;
      return false;
    }

    // We started the reload from a list state — wait for its result instead
    // of dispatching again from the same state (prevents an infinite loop).
    if (list != null && _awaitingReload) return true;
    if (list != null) _awaitingReload = true;

    if (!_isCurrentRoute()) {
      return true; // stay on spinner until we regain focus
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_isCurrentRoute()) return;
      context.read<ItemBloc>().add(LoadItemDetails(widget.itemId));
    });
    return true;
  }

  /// True when this screen is the current (topmost) route. Used to avoid
  /// dispatching loads while a child screen (e.g. the edit screen) is on top.
  bool _isCurrentRoute() => (ModalRoute.of(context)?.isCurrent ?? true);

  List<ItemWithDetails>? _itemsListFrom(ItemState state) {
    if (state is ItemsLoaded) return state.items;
    if (state is ItemsFiltered) return state.items;
    if (state is ItemSearchResults) return state.results;
    if (state is ItemDetailsLoaded) return state.allItems;
    return null;
  }

  Future<void> _deleteItem(ItemWithDetails item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text('Are you sure you want to delete "${item.item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final completion = Completer<void>();
      context.read<ItemBloc>().add(
        DeleteItem(item.item.id!, completion: completion),
      );
      try {
        await completion.future;
        if (mounted) Navigator.pop(context);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete item')),
          );
        }
      }
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EditItemScreen(itemId: widget.itemId)),
    );
    if (!mounted) return;
    context.read<ItemBloc>().add(LoadItemDetails(widget.itemId));
  }

  Future<void> _shareWholeItem(ItemWithDetails item) async {
    final service = context.read<ItemPdfService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final passwordFields = item.fields
        .where((f) => f.fieldType == FieldType.password && f.id != null)
        .toList();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Preparing PDF\u2026')),
          ],
        ),
      ),
    );

    try {
      // Spec §7: reading stored secrets requires a fresh biometric/PIN check.
      // Passwords are only decrypted when the check succeeds; declined checks
      // still export the rows, masked, so nothing is silently dropped.
      Map<int, String>? passwordValues;
      if (passwordFields.isNotEmpty) {
        final authenticated = await AuthService().authenticate();
        if (authenticated && mounted) {
          final repo = context.read<ItemRepository>();
          passwordValues = <int, String>{};
          for (final field in passwordFields) {
            final value = await repo.readPasswordField(field.id!);
            if (value != null && value.isNotEmpty) {
              passwordValues[field.id!] = value;
            }
          }
        }
      }

      final bytes = await service.buildItemPdf(
        item,
        passwordValues: passwordValues,
      );
      var fileName = service.fileNameForTitle(item.item.title);
      try {
        final filePath = await service.writeShareFile(bytes, item.item.title);
        fileName = p.basename(filePath);
      } catch (_) {
        // The preview can still share the in-memory PDF if temporary storage
        // is unavailable.
      }
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss the loading dialog
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ItemPdfPreviewScreen(
            bytes: bytes,
            fileName: fileName,
          ),
        ),
      );
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to create PDF')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          BlocBuilder<ItemBloc, ItemState>(
            builder: (context, state) {
              if (state is ItemDetailsLoaded &&
                  state.item.item.id == widget.itemId) {
                final item = state.item;
                return Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        item.item.favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: item.item.favorite ? cs.tertiary : null,
                      ),
                      tooltip: item.item.favorite ? 'Unfavorite' : 'Favorite',
                      onPressed: () {
                        context.read<ItemBloc>().add(
                          ToggleFavorite(item.item.id!, !item.item.favorite),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      tooltip: 'Share',
                      onPressed: () => _shareWholeItem(item),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'edit') {
                          _openEdit();
                        } else if (val == 'delete') {
                          _deleteItem(item);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: BlocBuilder<ItemBloc, ItemState>(
        builder: (context, state) {
          if (state is ItemError) {
            return Center(child: Text(state.message));
          }
          if (state is ItemDetailsLoaded &&
              state.item.item.id == widget.itemId) {
            final item = state.item;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.pageMargin,
                AppSpacing.pageMargin,
                AppSpacing.massive + AppSpacing.fabMargin,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Header: category pill → title → tags
                  if (item.categoryName != null) ...[
                    _CategoryPill(name: item.categoryName!),
                    AppSpacing.xl.hBox,
                  ],
                  Text(
                    item.item.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  if (item.item.tags.isNotEmpty) ...[
                    AppSpacing.md.hBox,
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: item.item.tags
                          .map(
                            (t) => Chip(
                              label: Text(
                                t,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              backgroundColor: cs.surfaceContainerHigh,
                              side: BorderSide.none,
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  AppSpacing.sectionGap.hBox,

                  // 1b. Photo carousel (swipe left/right through images)
                  if (item.attachments.any((a) => a.isPhoto)) ...[
                    _PhotoCarousel(
                      photos: item.attachments.where((a) => a.isPhoto).toList(),
                      controller: _photoController,
                      initialIndex: _currentPhotoIndex,
                      onPageChanged: (index) =>
                          setState(() => _currentPhotoIndex = index),
                    ),
                    AppSpacing.sectionGap.hBox,
                  ],

                  // 2. Nearest-expiry highlight
                  if (item.nearestDateField != null) ...[
                    _NearestExpiryHighlight(field: item.nearestDateField!),
                    AppSpacing.sectionGap.hBox,
                  ],

                  // 3. Fields list
                  if (item.fields.isNotEmpty) ...[
                    _SectionLabel('Fields'),
                    AppSpacing.md.hBox,
                    _buildFieldsList(item.fields),
                    AppSpacing.sectionGap.hBox,
                  ],

                  // 4. Attachments (photos are shown in the carousel above — this grid
                  //     shows the non-photo documents, e.g. PDFs)
                  if (item.attachments.any((a) => !a.isPhoto)) ...[
                    _SectionLabel('Documents'),
                    AppSpacing.md.hBox,
                    AttachmentGrid(
                      attachments: item.attachments
                          .where((a) => !a.isPhoto)
                          .toList(),
                      showDelete: true,
                      onDelete: (attachment) {
                        if (attachment.id == null) return;
                        context.read<ItemBloc>().add(
                          DeleteAttachment(
                            attachmentId: attachment.id!,
                            path: attachment.path,
                            itemId: attachment.itemId,
                          ),
                        );
                      },
                    ),
                    AppSpacing.sectionGap.hBox,
                  ],

                  // 5. Notes
                  if (item.item.notes != null &&
                      item.item.notes!.isNotEmpty) ...[
                    _SectionLabel('Notes'),
                    AppSpacing.md.hBox,
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(AppSpacing.cardPadding),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        item.item.notes!,
                        style: TextStyle(
                          fontSize: 15,
                          color: cs.onSurface,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          // ItemLoading, or any state that does not belong to this item's
          // details (ItemInitial, ItemsLoaded, ItemOperationSuccess, stale
          // ItemDetailsLoaded for another item). Re-request the item and show
          // a progress indicator — or, when the item no longer exists, show a
          // graceful "not found" placeholder instead of looping forever.
          final showSpinner = _ensureItemDetails(state);
          return showSpinner
              ? const Center(child: CircularProgressIndicator())
              : const _ItemGoneView();
        },
      ),
    );
  }

  Widget _buildFieldsList(List<ItemField> fields) {
    if (fields.length <= AppConstants.fieldsCollapseThreshold ||
        !_fieldsCollapsed) {
      return _wrapFieldsCard(_buildFieldCells(fields));
    }

    // Collapsed state
    var visibleCount = AppConstants.fieldsCollapseThreshold;
    if (visibleCount < fields.length &&
        _isLoginPair(fields[visibleCount - 1], fields[visibleCount])) {
      visibleCount++;
    }
    final hiddenCount = fields.length - visibleCount;
    final visibleCells = _buildFieldCells(fields.take(visibleCount).toList());

    return _wrapFieldsCard(
      visibleCells,
      trailing: TextButton(
        onPressed: () => setState(() => _fieldsCollapsed = false),
        child: Text('Show all $hiddenCount more fields'),
      ),
    );
  }

  List<Widget> _buildFieldCells(List<ItemField> fields) {
    final widgets = <Widget>[];
    for (var index = 0; index < fields.length; index++) {
      final field = fields[index];
      final next = index + 1 < fields.length ? fields[index + 1] : null;
      final isLogin =
          field.fieldType == FieldType.text &&
          field.label.trim().toLowerCase() == 'username' &&
          next?.fieldType == FieldType.password &&
          next?.label.trim().toLowerCase() == 'password';

      if (isLogin) {
        widgets.add(
          LoginDetailBlock(
            title: field.loginTitle ?? '',
            username: field,
            password: next!,
            onRevealPassword: () => _revealPassword(next),
            bordered: true,
          ),
        );
        index++;
      } else {
        widgets.add(
          FieldRowWidget(
            field: field,
            includeContainer: true,
            onRevealRequested: field.fieldType == FieldType.password
                ? () async => _revealPassword(field)
                : null,
          ),
        );
      }
    }
    return widgets;
  }

  bool _isLoginPair(ItemField username, ItemField password) {
    return username.fieldType == FieldType.text &&
        username.label.trim().toLowerCase() == 'username' &&
        password.fieldType == FieldType.password &&
        password.label.trim().toLowerCase() == 'password';
  }

  Future<String?> _revealPassword(ItemField field) async {
    final repo = context.read<ItemRepository>();
    final authenticated = await AuthService().authenticate();
    if (!authenticated) return null;
    return repo.readPasswordField(field.id!);
  }

  /// Keeps each field as a distinct block with a small visual gap between it
  /// and the next field.
  Widget _wrapFieldsCard(List<Widget> cells, {Widget? trailing}) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) children.add(AppSpacing.sm.hBox);
      children.add(cells[i]);
    }
    if (trailing != null) {
      children.add(
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              0,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: trailing,
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _NearestExpiryHighlight extends StatelessWidget {
  final ItemField field;
  const _NearestExpiryHighlight({required this.field});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = field.daysRemaining;
    if (days == null) return const SizedBox.shrink();

    Color bgColor, iconColor;
    String text;
    IconData icon;

    if (days < 0) {
      bgColor = cs.errorContainer;
      iconColor = cs.error;
      text = '${field.label} expired ${days.abs()} days ago.';
      icon = Icons.warning_rounded;
    } else if (days <= 30) {
      bgColor = cs.tertiaryContainer;
      iconColor = cs.tertiary;
      text = '${field.label} expires in $days days.';
      icon = Icons.schedule_rounded;
    } else {
      bgColor = cs.primaryContainer;
      iconColor = cs.primary;
      text = '${field.label} expires in $days days.';
      icon = Icons.check_circle_outline_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.cardPadding,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          AppSpacing.md.w,
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: cs.onSurfaceVariant,
      ),
    );
  }
}

/// Breadcrumb-style pill shown above an item title in the details header.
class _CategoryPill extends StatelessWidget {
  final String name;
  const _CategoryPill({required this.name});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_rounded, size: 15, color: cs.primary),
          AppSpacing.xs.w,
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatelessWidget {
  final List<Attachment> photos;
  final PageController controller;
  final int initialIndex;
  final ValueChanged<int> onPageChanged;

  const _PhotoCarousel({
    required this.photos,
    required this.controller,
    required this.initialIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (photos.isEmpty) return const SizedBox.shrink();
    final activeIndex = initialIndex.clamp(0, photos.length - 1);
    final activeRatio = photos[activeIndex].aspectRatio ?? 0.75;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: activeRatio > 0 ? activeRatio : 0.75,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              color: cs.surfaceContainerHigh,
              child: PageView.builder(
                controller: controller,
                itemCount: photos.length,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  final photo = photos[index];
                  final path = photo.path;
                  final file = File(path);
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final size = fitAspectRatioBox(
                        ratio: photo.aspectRatio ?? 0.75,
                        maxWidth: constraints.maxWidth,
                        maxHeight: constraints.maxHeight,
                      );
                      return Center(
                        child: SizedBox(
                          width: size.width,
                          height: size.height,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => FullScreenImageViewer(
                                    path: path,
                                    attachmentId: photo.id,
                                    itemId: photo.itemId,
                                  ),
                                ),
                              ),
                              child: file.existsSync()
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _PhotoPlaceholder(cs: cs),
                                    )
                                  : _PhotoPlaceholder(cs: cs),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        AppSpacing.md.hBox,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(photos.length, (i) {
            final isActive = i == initialIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              width: isActive ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: isActive ? cs.primary : cs.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  final ColorScheme cs;
  const _PhotoPlaceholder({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 48,
        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}

/// Shown when the item this screen was opened for no longer exists (deleted).
/// Prevents a permanent loading spinner / reload loop after a delete.
class _ItemGoneView extends StatelessWidget {
  const _ItemGoneView();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_outline_rounded,
              size: 56,
              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            AppSpacing.lg.hBox,
            Text(
              'Item not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            AppSpacing.inlineGap.hBox,
            Text(
              'This item may have been deleted.',
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            AppSpacing.xl.hBox,
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
