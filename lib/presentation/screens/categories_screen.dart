import 'package:flutter/material.dart';
import '../../data/models/category.dart';
import '../../data/repositories/item_repository.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final ItemRepository _repo = ItemRepository();
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _repo.getAllCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({Category? category}) async {
    final isEditing = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Category' : 'Add Category'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a category name')),
                );
                return;
              }
              Navigator.pop(context, name);
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        if (isEditing) {
          final updated = category.copyWith(name: result);
          await _repo.updateCategory(updated);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category updated successfully')),
            );
          }
        } else {
          final newCat = Category(name: result, isPreset: false);
          await _repo.createCategory(newCat);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category added successfully')),
            );
          }
        }
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(Category category) async {
    if (category.isPreset) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete preset categories')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete "${category.name}"? Items in this category will become uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _repo.deleteCategory(category.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
        }
        _loadCategories();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(title: const Text('Manage Categories')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories found'))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: _CategoryRow(
                        category: category,
                        cs: cs,
                        onEdit: category.isPreset
                            ? null
                            : () => _showAddEditDialog(category: category),
                        onDelete: category.isPreset
                            ? null
                            : () => _deleteCategory(category),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Category'),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final ColorScheme cs;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.category,
    required this.cs,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.folder_rounded, size: 20, color: cs.onPrimaryContainer),
      ),
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: category.isPreset
          ? const Text('Preset', style: TextStyle(fontSize: 12))
          : const Text('Custom', style: TextStyle(fontSize: 12)),
      trailing: category.isPreset
          ? Icon(Icons.lock_outline, color: cs.onSurfaceVariant, size: 20)
          : PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit?.call();
                } else if (value == 'delete') {
                  onDelete?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
    );
  }
}
