import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/category.dart';
import '../../data/models/item_field.dart';
import '../../data/models/item_with_details.dart';
import '../../data/repositories/item_repository.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../bloc/item/item_state.dart';
import '../widgets/dashboard_stats_widget.dart';
import '../widgets/favorite_seal_widget.dart';
import '../widgets/status_badge_widget.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class ItemsListScreen extends StatefulWidget {
  final VoidCallback? onSettingsNavigationStart;
  final VoidCallback? onSettingsNavigationEnd;

  const ItemsListScreen({
    super.key,
    this.onSettingsNavigationStart,
    this.onSettingsNavigationEnd,
  });

  @override
  State<ItemsListScreen> createState() => _ItemsListScreenState();
}

class _ItemsListScreenState extends State<ItemsListScreen> {
  List<Category> _categories = [];
  int? _activeCategoryId;

  // Local mirror of the last real list data. Rendered for ANY bloc state that
  // isn't the loaded list (including ItemDetailsLoaded, ItemOperationSuccess,
  // ItemLoading) so the home screen is never replaced by a spinner after an
  // edit/save or when a detail screen is stacked on top.
  List<ItemWithDetails>? _cachedItems;
  DashboardStats? _cachedStats;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await context.read<ItemRepository>().getAllCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _reload() {
    context.read<ItemBloc>().add(const LoadItems());
  }

  /// Requests the full list once (cold start only). Never re-dispatches once
  /// the list has been loaded, and never dispatches while a child route (such
  /// as the detail screen) is on top — otherwise the list would fight the
  /// detail screen's owns reloads and loop forever.
  void _ensureItemsLoaded(ItemState state) {
    if (state is ItemLoading) return;
    if (state is ItemError) return;
    if (_hasLoaded || _cachedItems != null) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
      context.read<ItemBloc>().add(const LoadItems());
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: BlocConsumer<ItemBloc, ItemState>(
        listener: (context, state) {
          if (state is ItemOperationSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is ItemError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: cs.error),
            );
          }
        },
        builder: (context, state) {
          // Mirror any data-carrying state into the local cache so rendering
          // below never depends on the exact state type arriving.
          if (state is ItemsLoaded) {
            _cachedItems = state.items;
            _cachedStats = state.stats;
          } else if (state is ItemsFiltered) {
            _cachedItems = state.items;
            _cachedStats = state.stats;
          } else if (state is ItemSearchResults) {
            _cachedItems = state.results;
          } else if (state is ItemDetailsLoaded) {
            if (state.allItems != null) _cachedItems = state.allItems;
            if (state.stats != null) _cachedStats = state.stats;
          }

          final items = _cachedItems ?? const <ItemWithDetails>[];
          final stats = _cachedStats ?? const DashboardStats();
          final hasData = _cachedItems != null;
          if (hasData) _hasLoaded = true;

          Widget content;
          if (state is ItemLoading && !hasData) {
            content = const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (state is ItemError && !hasData) {
            content = SliverFillRemaining(
              child: _ErrorState(message: state.message, onRetry: _reload),
            );
          } else if (hasData && items.isNotEmpty) {
            content = SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ItemCard(
                    item: items[index],
                    onTap: () => _openDetail(items[index]),
                  ),
                  childCount: items.length,
                ),
              ),
            );
          } else if (hasData) {
            content = SliverFillRemaining(child: _EmptyState());
          } else {
            // Cold start (ItemInitial) — request the list and show a spinner.
            // Never shows a blank/empty state on the very first frame.
            _ensureItemsLoaded(state);
            content = const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return CustomScrollView(
            slivers: [
              _buildAppBar(context, cs),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: DashboardStatsWidget(stats: stats),
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryFilterRow(
                  categories: _categories,
                  activeCategoryId: _activeCategoryId,
                  onCategorySelected: _onCategorySelected,
                ),
              ),
              content,
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      pinned: false,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 20,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/logo.png',
              width: 34,
              height: 34,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.inventory_2_rounded,
                size: 34,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Kipt',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: _openSearch,
          tooltip: 'Search',
        ),
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: _openSettings,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _onCategorySelected(int? catId) {
    setState(() => _activeCategoryId = catId);
    context.read<ItemBloc>().add(FilterItemsByCategory(catId));
  }

  /// Re-fetches the list after returning from a child screen. The home screen
  /// is NOT rebuilt while an opaque route (Add/Edit/Detail/Search/Settings) is
  /// on top, so it never saw the bloc states those screens produced — it must
  /// explicitly reload once visible again. LoadItems skips the loading state
  /// when a cache already exists, so this refresh is flicker-free.
  void _refreshAfterReturn() {
    if (!mounted) return;
    if (_activeCategoryId != null) {
      context.read<ItemBloc>().add(FilterItemsByCategory(_activeCategoryId));
    } else {
      context.read<ItemBloc>().add(const LoadItems());
    }
  }

  void _openDetail(ItemWithDetails item) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(itemId: item.item.id!),
          ),
        )
        .then((_) => _refreshAfterReturn());
  }

  void _openAddItem() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddItemScreen())).then(
      (_) => _refreshAfterReturn(),
    );
  }

  void _openSearch() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SearchScreen())).then(
      (_) => _refreshAfterReturn(),
    );
  }

  void _openSettings() {
    widget.onSettingsNavigationStart?.call();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())).then((_) {
      if (!mounted) return;
      widget.onSettingsNavigationEnd?.call();
      _loadCategories();
      _refreshAfterReturn();
    });
  }
}

// ---------------------------------------------------------------------------
// Category filter row
// ---------------------------------------------------------------------------

class _CategoryFilterRow extends StatelessWidget {
  final List<Category> categories;
  final int? activeCategoryId;
  final ValueChanged<int?> onCategorySelected;

  const _CategoryFilterRow({
    required this.categories,
    required this.activeCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemCount: categories.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _FilterChip(
                label: 'All',
                selected: activeCategoryId == null,
                onTap: () => onCategorySelected(null),
                cs: cs,
              );
            }
            final cat = categories[index - 1];
            return _FilterChip(
              label: cat.name,
              selected: activeCategoryId == cat.id,
              onTap: () => onCategorySelected(cat.id),
              cs: cs,
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(21),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? cs.onPrimary : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item card
// ---------------------------------------------------------------------------

class _ItemCard extends StatelessWidget {
  final ItemWithDetails item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

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
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: _Thumbnail(attachment: item.firstPhoto, cs: cs),
                ),
                const SizedBox(width: 14),
                // Content
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
                // Status badge
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
  final dynamic attachment; // Attachment?
  final ColorScheme cs;

  const _Thumbnail({required this.attachment, required this.cs});

  @override
  Widget build(BuildContext context) {
    if (attachment == null) {
      return Container(
        width: 60,
        height: 60,
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing here yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to add your first item',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: 16),
            Text(
              'Could not load items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
