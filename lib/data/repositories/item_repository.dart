import '../database/database_helper.dart';
import '../models/item.dart';
import '../models/item_field.dart';
import '../models/attachment.dart';
import '../models/category.dart';
import '../models/item_with_details.dart';
import '../../core/utils/camera_aspect_ratio.dart';
import 'secure_field_service.dart';
import 'notification_service.dart';
import 'image_storage_service.dart';

class ItemRepository {
  final DatabaseHelper _db;
  final SecureFieldService _secureField;
  final NotificationService _notifications;
  final ImageStorageService _imageStorage;

  ItemRepository({
    DatabaseHelper? databaseHelper,
    SecureFieldService? secureFieldService,
    NotificationService? notificationService,
    ImageStorageService? imageStorageService,
  }) : _db = databaseHelper ?? DatabaseHelper(),
       _secureField = secureFieldService ?? SecureFieldService(),
       _notifications = notificationService ?? NotificationService(),
       _imageStorage = imageStorageService ?? ImageStorageService();

  // ---------------------------------------------------------------------------
  // Item operations
  // ---------------------------------------------------------------------------

  /// Creates an item with its fields and attachments in a single transaction.
  Future<int> createItem({
    required Item item,
    required List<ItemField> fields,
    required List<String> attachmentPaths, // temporary file paths
  }) async {
    final now = DateTime.now();
    final itemToInsert = item.copyWith(createdAt: now, updatedAt: now);
    final itemId = await _db.insertItem(itemToInsert);

    await _saveFields(itemId, fields, item.title);
    await _saveAttachments(itemId, attachmentPaths);

    return itemId;
  }

  /// Updates an item, replacing all its fields.
  /// [deletedFieldIds] — field IDs to delete (cancels their reminders).
  /// [deletedAttachmentIds] — attachment IDs whose files should be deleted.
  Future<void> updateItem({
    required Item item,
    required List<ItemField> fields,
    List<int> deletedFieldIds = const [],
    List<String> newAttachmentPaths = const [],
    List<int> deletedAttachmentIds = const [],
  }) async {
    final updatedItem = item.copyWith(updatedAt: DateTime.now());
    await _db.updateItem(updatedItem);

    // Cancel reminders for deleted fields
    for (final fId in deletedFieldIds) {
      await _notifications.cancelFieldReminder(fId);
      await _secureField.deletePassword(fId);
      await _db.deleteField(fId);
    }

    // Delete attachment files/records
    for (final aId in deletedAttachmentIds) {
      final attachments = await _db.getAttachmentsByItemId(item.id!);
      final toDelete = attachments.where((a) => a.id == aId).firstOrNull;
      if (toDelete != null) {
        await _imageStorage.deleteImage(toDelete.path);
        await _db.deleteAttachment(aId);
      }
    }

    // Upsert fields
    await _saveFields(item.id!, fields, item.title);

    // Add new attachments
    await _saveAttachments(item.id!, newAttachmentPaths);
  }

  /// Deletes an item and all associated data, cancelling any scheduled reminders.
  Future<void> deleteItem(int itemId) async {
    final fields = await _db.getFieldsByItemId(itemId);
    final attachments = await _db.getAttachmentsByItemId(itemId);

    // Cancel reminders and clean up secure storage
    await _notifications.cancelFieldReminders(fields);
    final passwordFieldIds = fields
        .where((f) => f.fieldType == FieldType.password && f.id != null)
        .map((f) => f.id!)
        .toList();
    await _secureField.deletePasswords(passwordFieldIds);

    // Delete attachment files from disk
    for (final attachment in attachments) {
      await _imageStorage.deleteImage(attachment.path);
    }

    await _db.deleteItem(itemId);
  }

  Future<Item?> getItemById(int id) => _db.getItemById(id);

  Future<List<Item>> getAllItems() => _db.getAllItems();

  Future<ItemWithDetails?> getItemWithDetails(int itemId) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return null;

    final fields = await _db.getFieldsByItemId(itemId);
    final attachments = await _db.getAttachmentsByItemId(itemId);
    String? categoryName;
    if (item.categoryId != null) {
      final cat = await _db.getCategoryById(item.categoryId!);
      categoryName = cat?.name;
    }

    return ItemWithDetails(
      item: item,
      fields: fields,
      attachments: attachments,
      categoryName: categoryName,
    );
  }

  Future<List<ItemWithDetails>> getAllItemsWithDetails() async {
    final items = await _db.getAllItems();
    final List<ItemWithDetails> result = [];

    // Batch load all categories once
    final categories = await _db.getAllCategories();
    final catMap = {for (final c in categories) c.id!: c.name};

    for (final item in items) {
      result.add(await _loadItemWithDetails(item, catMap));
    }
    return result;
  }

  /// Loads a single item's fields and attachments. A failure on one item
  /// (e.g. corrupt data) must not prevent the rest of the list from loading.
  Future<ItemWithDetails> _loadItemWithDetails(
    Item item,
    Map<int, String> catMap,
  ) async {
    try {
      final fields = await _db.getFieldsByItemId(item.id!);
      final attachments = await _db.getAttachmentsByItemId(item.id!);
      return ItemWithDetails(
        item: item,
        fields: fields,
        attachments: attachments,
        categoryName: item.categoryId != null ? catMap[item.categoryId] : null,
      );
    } catch (_) {
      return ItemWithDetails(
        item: item,
        fields: const [],
        attachments: const [],
        categoryName: item.categoryId != null ? catMap[item.categoryId] : null,
      );
    }
  }

  /// Search items by title, tags, and non-PASSWORD field labels/values (spec §3.5).
  Future<List<ItemWithDetails>> searchItems(String query) async {
    if (query.trim().isEmpty) return getAllItemsWithDetails();
    final ids = await _db.searchItemIds(query.trim());
    final List<ItemWithDetails> result = [];
    for (final id in ids) {
      final d = await getItemWithDetails(id);
      if (d != null) result.add(d);
    }
    return result;
  }

  Future<List<ItemWithDetails>> getItemsByCategory(int categoryId) async {
    final items = await _db.getItemsByCategory(categoryId);
    final cat = await _db.getCategoryById(categoryId);
    final List<ItemWithDetails> result = [];
    final catMap = {if (cat?.id != null) cat!.id!: cat.name};
    for (final item in items) {
      result.add(await _loadItemWithDetails(item, catMap));
    }
    return result;
  }

  Future<bool> toggleFavorite(int itemId, bool value) async {
    final item = await _db.getItemById(itemId);
    if (item == null) return false;
    await _db.updateItem(item.copyWith(favorite: value));
    return true;
  }

  // ---------------------------------------------------------------------------
  // Dashboard stats (spec §5)
  // ---------------------------------------------------------------------------

  Future<DashboardStats> getDashboardStats() async {
    final fields = await _db.getAllReminderDateFields();
    int active = 0, expiringSoon = 0, expired = 0;
    for (final f in fields) {
      switch (f.status) {
        case FieldStatus.active:
          active++;
          break;
        case FieldStatus.expiringSoon:
          expiringSoon++;
          break;
        case FieldStatus.expired:
          expired++;
          break;
        case FieldStatus.noReminder:
          break;
      }
    }
    return DashboardStats(
      active: active,
      expiringSoon: expiringSoon,
      expired: expired,
    );
  }

  // ---------------------------------------------------------------------------
  // Category operations
  // ---------------------------------------------------------------------------

  Future<List<Category>> getAllCategories() => _db.getAllCategories();
  Future<Category?> getCategoryById(int id) => _db.getCategoryById(id);
  Future<int> createCategory(Category category) => _db.insertCategory(category);
  Future<void> updateCategory(Category category) =>
      _db.updateCategory(category);
  Future<void> deleteCategory(int id) => _db.deleteCategory(id);

  // ---------------------------------------------------------------------------
  // Attachment operations
  // ---------------------------------------------------------------------------

  Future<List<Attachment>> getAttachments(int itemId) =>
      _db.getAttachmentsByItemId(itemId);

  Future<void> deleteAttachmentById(int attachmentId, String path) async {
    await _imageStorage.deleteImage(path);
    await _db.deleteAttachment(attachmentId);
  }

  Future<List<Attachment>> getAllAttachments() => _db.getAllAttachments();

  // ---------------------------------------------------------------------------
  // Password field operations
  // ---------------------------------------------------------------------------

  /// Reads the plaintext for a PASSWORD field (requires the fieldId).
  Future<String?> readPasswordField(int fieldId) =>
      _secureField.readPassword(fieldId);

  // ---------------------------------------------------------------------------
  // Data reset
  // ---------------------------------------------------------------------------

  Future<void> clearAllData() async {
    await _notifications.cancelAllNotifications();
    final attachments = await _db.getAllAttachments();
    for (final a in attachments) {
      await _imageStorage.deleteImage(a.path);
    }
    await _db.clearAllData();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Inserts or updates fields for an item. Fields with an existing ID are updated;
  /// new fields (id == null) are inserted. Schedules/reschedules notifications.
  Future<void> _saveFields(
    int itemId,
    List<ItemField> fields,
    String itemTitle,
  ) async {
    for (int i = 0; i < fields.length; i++) {
      final f = fields[i].copyWith(itemId: itemId, sortOrder: i);

      if (f.fieldType == FieldType.password) {
        // For PASSWORD fields, value is the plaintext the user entered.
        // We store it in secure storage and save the key reference in the DB.
        if (f.id != null) {
          // Update existing — only re-encrypt when the user entered a new value.
          // An empty value means "keep the previously stored secret" (used when
          // editing an item but leaving the password untouched).
          if (f.value.isNotEmpty) {
            await _secureField.storePassword(f.id!, f.value);
          }
          final key = '${SecureFieldService.prefix}${f.id}';
          await _db.updateField(f.copyWith(value: key));
        } else {
          // Insert first (to get an ID), then update with the key reference
          final tempField = f.copyWith(value: '[pending]');
          final newId = await _db.insertField(tempField);
          final key = await _secureField.storePassword(newId, f.value);
          await _db.updateField(
            f.copyWith(id: newId, value: key, itemId: itemId, sortOrder: i),
          );
        }
      } else {
        if (f.id != null) {
          await _db.updateField(f);
          if (f.fieldType == FieldType.date && f.reminderEnabled) {
            await _notifications.rescheduleFieldReminder(f, itemTitle);
          } else if (f.fieldType == FieldType.date && !f.reminderEnabled) {
            await _notifications.cancelFieldReminder(f.id!);
          }
        } else {
          final newId = await _db.insertField(f);
          if (f.fieldType == FieldType.date && f.reminderEnabled) {
            final inserted = f.copyWith(id: newId);
            await _notifications.scheduleFieldReminder(inserted, itemTitle);
          }
        }
      }
    }
  }

  /// Saves attachment files from temporary paths to app storage. Photo
  /// attachments get their width/height aspect ratio detected and stored so
  /// the UI can display them in a matching frame.
  Future<void> _saveAttachments(int itemId, List<String> paths) async {
    for (final path in paths) {
      final isPhoto = !path.toLowerCase().endsWith('.pdf');
      final mimetype = isPhoto ? 'image/jpeg' : 'application/pdf';
      final savedPath = await _imageStorage.saveImageFromPath(path);
      final ratio = isPhoto
          ? await PhotoRatioUtils.readImageAspectRatio(savedPath)
          : null;
      await _db.insertAttachment(
        Attachment(
          itemId: itemId,
          path: savedPath,
          isPhoto: isPhoto,
          mimetype: mimetype,
          addedAt: DateTime.now(),
          aspectRatio: ratio,
        ),
      );
    }
  }
}
