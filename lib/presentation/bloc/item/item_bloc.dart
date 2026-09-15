import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/item_repository.dart';
import '../../../data/models/item_with_details.dart';
import 'item_event.dart';
import 'item_state.dart';

class ItemBloc extends Bloc<ItemEvent, ItemState> {
  final ItemRepository itemRepository;

  List<ItemWithDetails>? _cachedItems;
  DashboardStats? _cachedStats;

  ItemBloc({required this.itemRepository}) : super(ItemInitial()) {
    on<LoadItems>(_onLoadItems);
    on<LoadItemDetails>(_onLoadItemDetails);
    on<CreateItem>(_onCreateItem);
    on<UpdateItem>(_onUpdateItem);
    on<DeleteItem>(_onDeleteItem);
    on<ToggleFavorite>(_onToggleFavorite);
    on<SearchItems>(_onSearchItems);
    on<FilterItemsByCategory>(_onFilterByCategory);
    on<LoadDashboardStats>(_onLoadDashboardStats);
    on<DeleteAttachment>(_onDeleteAttachment);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<(List<ItemWithDetails>, DashboardStats)> _loadAll() async {
    final items = await itemRepository.getAllItemsWithDetails();
    final stats = await itemRepository.getDashboardStats();
    _cachedItems = items;
    _cachedStats = stats;
    return (items, stats);
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  Future<void> _onLoadItems(LoadItems event, Emitter<ItemState> emit) async {
    try {
      // Skip the loading state when we already have cached data so the list
      // stays visible while refreshing (e.g. navigating back from details).
      if (_cachedItems == null) {
        emit(ItemLoading());
      }
      final (items, stats) = await _loadAll();
      emit(ItemsLoaded(items, stats));
    } catch (e) {
      emit(ItemError('Failed to load items: $e'));
    }
  }

  Future<void> _onLoadItemDetails(
    LoadItemDetails event,
    Emitter<ItemState> emit,
  ) async {
    try {
      // Preserve cached list so navigating back doesn't trigger a full reload
      if (state is ItemsLoaded) _cachedItems = (state as ItemsLoaded).items;
      if (state is ItemsLoaded) _cachedStats = (state as ItemsLoaded).stats;

      // Keep the current view visible (cached list) instead of flashing a
      // loading spinner when refreshing details.
      if (_cachedItems == null) {
        emit(ItemLoading());
      }
      final item = await itemRepository.getItemWithDetails(event.itemId);
      if (item != null) {
        emit(
          ItemDetailsLoaded(item, allItems: _cachedItems, stats: _cachedStats),
        );
      } else if (_cachedItems != null && _cachedStats != null) {
        // Item was deleted while we still have cached list data – fall back
        // to the list instead of showing a dead-end "Item not found" error.
        emit(ItemsLoaded(_cachedItems!, _cachedStats!));
      } else {
        emit(const ItemError('Item not found'));
      }
    } catch (e) {
      emit(ItemError('Failed to load item: $e'));
    }
  }

  Future<void> _onCreateItem(CreateItem event, Emitter<ItemState> emit) async {
    try {
      emit(ItemLoading());
      await itemRepository.createItem(
        item: event.item,
        fields: event.fields,
        attachmentPaths: event.attachmentPaths,
      );
      final (items, stats) = await _loadAll();
      emit(ItemsLoaded(items, stats));
      emit(const ItemOperationSuccess('Item created successfully'));
      event.completion?.complete();
    } catch (e) {
      event.completion?.completeError(e);
      emit(ItemError('Failed to create item: $e'));
    }
  }

  Future<void> _onUpdateItem(UpdateItem event, Emitter<ItemState> emit) async {
    try {
      emit(ItemLoading());
      await itemRepository.updateItem(
        item: event.item,
        fields: event.fields,
        deletedFieldIds: event.deletedFieldIds,
        newAttachmentPaths: event.newAttachmentPaths,
        deletedAttachmentIds: event.deletedAttachmentIds,
      );
      // Reload detail view after update
      final item = await itemRepository.getItemWithDetails(event.item.id!);
      final (allItems, stats) = await _loadAll();
      if (item != null) {
        emit(ItemDetailsLoaded(item, allItems: allItems, stats: stats));
      } else {
        emit(ItemsLoaded(allItems, stats));
      }
      emit(const ItemOperationSuccess('Item updated successfully'));
      event.completion?.complete();
    } catch (e) {
      event.completion?.completeError(e);
      emit(ItemError('Failed to update item: $e'));
    }
  }

  Future<void> _onDeleteItem(DeleteItem event, Emitter<ItemState> emit) async {
    try {
      emit(ItemLoading());
      await itemRepository.deleteItem(event.itemId);
      final (items, stats) = await _loadAll();
      emit(ItemsLoaded(items, stats));
      emit(const ItemOperationSuccess('Item deleted'));
      event.completion?.complete();
    } catch (e) {
      event.completion?.completeError(e);
      emit(ItemError('Failed to delete item: $e'));
    }
  }

  Future<void> _onToggleFavorite(
    ToggleFavorite event,
    Emitter<ItemState> emit,
  ) async {
    try {
      await itemRepository.toggleFavorite(event.itemId, event.value);
      // Soft-update the cached list without a full reload
      final (items, stats) = await _loadAll();
      if (state is ItemDetailsLoaded) {
        final updated = await itemRepository.getItemWithDetails(event.itemId);
        if (updated != null) {
          emit(ItemDetailsLoaded(updated, allItems: items, stats: stats));
        }
      } else {
        emit(ItemsLoaded(items, stats));
      }
    } catch (e) {
      emit(ItemError('Failed to toggle favorite: $e'));
    }
  }

  Future<void> _onSearchItems(
    SearchItems event,
    Emitter<ItemState> emit,
  ) async {
    try {
      emit(ItemLoading());
      if (event.query.isEmpty) {
        final (items, stats) = await _loadAll();
        emit(ItemsLoaded(items, stats));
      } else {
        final results = await itemRepository.searchItems(event.query);
        emit(ItemSearchResults(results, event.query));
      }
    } catch (e) {
      emit(ItemError('Failed to search: $e'));
    }
  }

  Future<void> _onFilterByCategory(
    FilterItemsByCategory event,
    Emitter<ItemState> emit,
  ) async {
    try {
      // Skip the loading state when we already have cached data so refreshing
      // through a filter (e.g. navigating back from details) stays flicker-free.
      if (_cachedItems == null) {
        emit(ItemLoading());
      }
      if (event.categoryId == null) {
        final (items, stats) = await _loadAll();
        emit(ItemsLoaded(items, stats));
      } else {
        final items = await itemRepository.getItemsByCategory(
          event.categoryId!,
        );
        final stats = await itemRepository.getDashboardStats();
        _cachedItems = items;
        _cachedStats = stats;
        emit(ItemsFiltered(items, event.categoryId!, stats));
      }
    } catch (e) {
      emit(ItemError('Failed to filter: $e'));
    }
  }

  Future<void> _onLoadDashboardStats(
    LoadDashboardStats event,
    Emitter<ItemState> emit,
  ) async {
    try {
      final stats = await itemRepository.getDashboardStats();
      _cachedStats = stats;
    } catch (_) {}
  }

  Future<void> _onDeleteAttachment(
    DeleteAttachment event,
    Emitter<ItemState> emit,
  ) async {
    try {
      await itemRepository.deleteAttachmentById(event.attachmentId, event.path);
      final item = await itemRepository.getItemWithDetails(event.itemId);
      if (item != null) {
        emit(
          ItemDetailsLoaded(item, allItems: _cachedItems, stats: _cachedStats),
        );
        emit(const ItemOperationSuccess('Attachment deleted'));
      }
    } catch (e) {
      emit(ItemError('Failed to delete attachment: $e'));
    }
  }
}
