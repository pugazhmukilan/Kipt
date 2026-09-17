import 'dart:io';
import 'package:flutter/material.dart';
import '../../data/models/item_field.dart';
import '../../data/models/item_with_details.dart';
import 'favorite_seal_widget.dart';
import 'status_badge_widget.dart';

/// Standard card used to represent a saved item in list and search screens.
///
/// Layout (left → right):
/// thumbnail · title (right: status badge) / category / nearest-date hint.
class ItemCard extends StatelessWidget {
  final ItemWithDetails item;
  final VoidCallback onTap;

  const ItemCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nearest = item.nearestDateField;
    final urgentStatus = item.mostUrgentStatus;
    final showBadge =
        urgentStatus != null && urgentStatus != FieldStatus.noReminder;
    final isFavorite = item.item.favorite;

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final imagePanelWidth = constraints.maxWidth / 3;
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: imagePanelWidth,
                            child: SizedBox.expand(
                              child: _Thumbnail(
                                attachment: item.firstPhoto,
                                cs: cs,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(width: imagePanelWidth - 12),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                            right: isFavorite ? 36 : 0,
                                          ),
                                          child: Text(
                                            item.item.title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.categoryName != null) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.folder_outlined,
                                          size: 13,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            item.categoryName!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (nearest != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Expanded(
                                          child: _NearestDateHint(
                                            field: nearest,
                                          ),
                                        ),
                                        if (showBadge) ...[
                                          const SizedBox(width: 8),
                                          StatusBadge(
                                            status: urgentStatus,
                                            compact: true,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ] else if (showBadge) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: StatusBadge(
                                        status: urgentStatus,
                                        compact: true,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (isFavorite)
          const Positioned(top: 8, right: 8, child: FavoriteSeal(size: 36)),
      ],
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final dynamic attachment; // Attachment?
  final ColorScheme cs;

  const _Thumbnail({required this.attachment, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (attachment == null) {
      return Container(
        color: cs.surfaceContainerHigh,
        child: Icon(
          Icons.inventory_2_rounded,
          color: cs.onSurfaceVariant,
          size: 26,
        ),
      );
    }
    final file = File(attachment!.path as String);
    if (!file.existsSync()) {
      return Container(
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      );
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}

class _NearestDateHint extends StatelessWidget {
  final ItemField field;
  const _NearestDateHint({required this.field});

  @override
  Widget build(BuildContext context) {
    final days = field.daysRemaining;
    if (days == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final String text;
    final Color accent;
    if (days < 0) {
      text = '${field.label} expired ${days.abs()}d ago';
      accent = cs.error;
    } else if (days == 0) {
      text = '${field.label} expires today';
      accent = cs.tertiary;
    } else {
      text = '${field.label} in ${days}d';
      accent = cs.onSurfaceVariant;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 12, color: accent),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
