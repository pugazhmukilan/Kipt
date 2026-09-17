import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/spacing.dart';
import '../../data/models/category.dart';
import '../../data/models/item_with_details.dart';
import '../../data/repositories/item_repository.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../bloc/item/item_state.dart';
import '../widgets/dashboard_stats_widget.dart';
import '../widgets/item_card_widget.dart';
import 'add_item_screen.dart';
import 'item_detail_screen.dart';
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
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final cats = await context.read<ItemRepository>().getAllCategories();
    if (mounted) setState(() => _categories = cats);
  }

  void _reload() {
    context.read<ItemBloc>().add(const LoadItems());
  }

  void _onSearchChanged(String query) {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      context.read<ItemBloc>().add(const LoadItems());
    } else {
      context.read<ItemBloc>().add(SearchItems(trimmedQuery));
    }
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddItem,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              padding: EdgeInsets.fromLTRB(
                AppSpacing.pageMargin,
                AppSpacing.searchBarVertical,
                AppSpacing.pageMargin,
                AppSpacing.massive + AppSpacing.fabMargin,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.listItemGap),
                    child: ItemCard(
                      item: items[index],
                      onTap: () => _openDetail(items[index]),
                    ),
                  ),
                  childCount: items.length,
                ),
              ),
            );
          } else if (state is ItemSearchResults && state.query.isNotEmpty) {
            content = SliverFillRemaining(
              child: _NoSearchResultsState(
                onClear: () {
                  _searchController.clear();
                  _onSearchChanged('');
                  _searchFocusNode.requestFocus();
                },
              ),
            );
          } else if (hasData) {
            content = SliverFillRemaining(
              child: _EmptyState(onAdd: _openAddItem),
            );
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search your items',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear_rounded),
                              tooltip: 'Clear search',
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin,
                    AppSpacing.searchBarVertical,
                    AppSpacing.pageMargin,
                    0,
                  ),
                  child: DashboardStatsWidget(stats: stats),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.lg,
                    left: AppSpacing.pageMargin,
                    right: AppSpacing.pageMargin,
                    bottom: AppSpacing.md,
                  ),
                  child: _CategoryFilterRow(
                    categories: _categories,
                    activeCategoryId: _activeCategoryId,
                    onCategorySelected: _onCategorySelected,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pageMargin,
                    AppSpacing.sm,
                    AppSpacing.pageMargin,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'Your items',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
              content,
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, ColorScheme cs) {
    return SliverAppBar(
      floating: true,
      pinned: false,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/logo.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  Icon(Icons.inventory_2_rounded, size: 30, color: cs.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Kipt',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_rounded),
          onPressed: _openSettings,
          tooltip: 'Settings',
        ),
        const SizedBox(width: 4),
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
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AddItemScreen()))
        .then((_) => _refreshAfterReturn());
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
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        separatorBuilder: (_, _) => SizedBox(width: AppSpacing.chipGap),
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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
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
// Empty / error states
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            AppSpacing.xl.hBox,
            Text(
              'Nothing here yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            AppSpacing.inlineGap.hBox,
            Text(
              'Add your first item to start tracking\nwarranties, receipts, and IDs.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            AppSpacing.sectionGap.hBox,
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add your first item'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResultsState extends StatelessWidget {
  final VoidCallback onClear;

  const _NoSearchResultsState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No matching items',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different title, category, or field.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear search'),
            ),
          ],
        ),
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
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            AppSpacing.lg.hBox,
            Text(
              'Could not load items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            AppSpacing.inlineGap.hBox,
            Text(
              message,
              style: TextStyle(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            AppSpacing.xl.hBox,
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
