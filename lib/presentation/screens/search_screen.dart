import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/spacing.dart';
import '../../data/models/item_with_details.dart';
import '../bloc/item/item_bloc.dart';
import '../bloc/item/item_event.dart';
import '../bloc/item/item_state.dart';
import '../widgets/item_card_widget.dart';
import 'item_detail_screen.dart';

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
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => ItemDetailScreen(itemId: item.item.id!),
          ),
        )
        .then((_) {
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
      appBar: AppBar(centerTitle: true, title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search title, tags, or fields',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (query) {
                _onSearchChanged(query);
                setState(() {});
              },
              textInputAction: TextInputAction.search,
            ),
          ),
          Expanded(
            child: BlocBuilder<ItemBloc, ItemState>(
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
                      title: 'Search Items',
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
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.pageMargin,
                      AppSpacing.md,
                      AppSpacing.pageMargin,
                      AppSpacing.massive + AppSpacing.fabMargin,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(bottom: AppSpacing.listItemGap),
                      child: ItemCard(
                        item: items[index],
                        onTap: () => _openDetail(items[index]),
                      ),
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    ColorScheme cs, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
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
              icon,
              size: 44,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          AppSpacing.xl.hBox,
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          AppSpacing.inlineGap.hBox,
          Text(subtitle, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
