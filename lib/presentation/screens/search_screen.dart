import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/item_with_details.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../bloc/item/item_state.dart';
import 'item_detail_screen.dart';
import '../widgets/favorite_seal_widget.dart';
import '../widgets/status_badge_widget.dart';
import 'dart:io';
import '../../data/models/item_field.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Start with empty search to show nothing
    context.read<ItemBloc>().add(const SearchItems(''));
    // Delay focus slightly so the keyboard animation is smooth
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    context.read<ItemBloc>().add(SearchItems(query));
  }

  void _openDetail(ItemWithDetails item) {
    // Unfocus keyboard before navigating
    _focusNode.unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemDetailScreen(itemId: item.item.id!),
      ),
    ).then((_) {
      // Reload items when coming back, but keep the search query active
      if (mounted) {
        context.read<ItemBloc>().add(SearchItems(_searchController.text));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(22),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search title, tags, or fields...',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                icon: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: Icon(Icons.search_rounded, size: 20, color: cs.onSurfaceVariant),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: InputBorder.none,
                fillColor: Colors.transparent,
              ),
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
            ),
          ),
        ),
      ),
      body: BlocBuilder<ItemBloc, ItemState>(
        builder: (context, state) {
          if (state is ItemLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ItemSearchResults) {
            final items = state.results;
            final query = state.query;

            if (query.isEmpty) {
              return _buildEmptyState(
                cs, 
                icon: Icons.search_rounded, 
                title: 'Search Kipt', 
                subtitle: 'Find items by title, tags, or fields',
              );
            }

            if (items.isEmpty) {
              return _buildEmptyState(
                cs, 
                icon: Icons.search_off_rounded, 
                title: 'No results found', 
                subtitle: 'Try adjusting your search terms',
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: items.length,
              itemBuilder: (context, index) {
                return _SearchResultCard(
                  item: items[index],
                  onTap: () => _openDetail(items[index]),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme cs, {required IconData icon, required String title, required String subtitle}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Same card style as ItemsListScreen but we define it here too (or share it)
// ---------------------------------------------------------------------------

class _SearchResultCard extends StatelessWidget {
  final ItemWithDetails item;
  final VoidCallback onTap;

  const _SearchResultCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nearest = item.nearestDateField;
    final urgentStatus = item.mostUrgentStatus;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _Thumbnail(
                attachment: item.firstPhoto,
                cs: cs,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.item.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (item.categoryName != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.categoryName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (nearest != null) ...[
                    const SizedBox(height: 6),
                    _NearestDateHint(field: nearest),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (urgentStatus != null && urgentStatus != FieldStatus.noReminder)
              StatusBadge(status: urgentStatus, compact: true),
          ],
        ),
      ),
          // Wax-stamp logo for favorites, on top of the card's top-right corner.
          if (item.item.favorite)
            Positioned(
              top: -12,
              right: -10,
              child: FavoriteSeal(),
            ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final dynamic attachment;
  final ColorScheme cs;

  const _Thumbnail({required this.attachment, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (attachment == null) {
      return Container(
        width: 60,
        height: 60,
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.inventory_2_rounded, color: cs.onSurfaceVariant, size: 26),
      );
    }
    final file = File(attachment!.path as String);
    if (!file.existsSync()) {
      return Container(
        width: 60,
        height: 60,
        color: cs.surfaceContainerHigh,
        child: Icon(Icons.broken_image_outlined, color: cs.onSurfaceVariant),
      );
    }
    return SizedBox(
      width: 60,
      height: 60,
      child: Image.file(file, fit: BoxFit.cover),
    );
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
    String text;
    if (days < 0) {
      text = '${field.label} expired ${days.abs()}d ago';
    } else if (days == 0) {
      text = '${field.label} expires today';
    } else {
      text = '${field.label} in ${days}d';
    }
    return Text(
      text,
      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
