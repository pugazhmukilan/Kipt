import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import '../models/item.dart';
import '../models/item_field.dart';
import '../models/attachment.dart';
import '../models/category.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ---------------------------------------------------------------------------
  // Schema creation (v8 — field-based model with login titles)
  // ---------------------------------------------------------------------------

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${AppConstants.tableItems} (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        title      TEXT    NOT NULL,
        category_id INTEGER,
        tags       TEXT    DEFAULT '[]',
        notes      TEXT,
        favorite   INTEGER DEFAULT 0,
        created_at TEXT    NOT NULL,
        updated_at TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableItemFields} (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id             INTEGER NOT NULL,
        label               TEXT    NOT NULL,
        field_type          TEXT    NOT NULL,
        value               TEXT    DEFAULT '',
        login_title         TEXT,
        reminder_enabled    INTEGER DEFAULT 0,
        reminder_lead_days  INTEGER,
        sort_order          INTEGER DEFAULT 0,
        FOREIGN KEY (item_id) REFERENCES ${AppConstants.tableItems} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableAttachments} (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id      INTEGER NOT NULL,
        path         TEXT    NOT NULL,
        is_photo     INTEGER DEFAULT 1,
        mimetype     TEXT    NOT NULL,
        added_at     TEXT    NOT NULL,
        aspect_ratio REAL,
        FOREIGN KEY (item_id) REFERENCES ${AppConstants.tableItems} (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${AppConstants.tableCategories} (
        id        INTEGER PRIMARY KEY AUTOINCREMENT,
        name      TEXT    NOT NULL UNIQUE,
        is_preset INTEGER DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_fields_item_id ON ${AppConstants.tableItemFields} (item_id)',
    );
    await db.execute(
      'CREATE INDEX idx_attachments_item_id ON ${AppConstants.tableAttachments} (item_id)',
    );
    await db.execute(
      'CREATE INDEX idx_fields_type_reminder ON ${AppConstants.tableItemFields} (field_type, reminder_enabled)',
    );

    await _seedCategories(db);
  }

  Future<void> _seedCategories(Database db) async {
    for (final name in AppConstants.presetCategoryNames) {
      await db.insert(AppConstants.tableCategories, {
        'name': name,
        'is_preset': 1,
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Migration — versions < 7 are incompatible; drop and recreate.
  // v7 → v8 adds the optional login_title column for login groups.
  // v8 → v9 adds the optional aspect_ratio column for photo attachments.
  // ---------------------------------------------------------------------------

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 7) {
      // Drop all legacy tables (order matters due to FK references)
      await db.execute('DROP TABLE IF EXISTS ocr_texts');
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableNotesLegacy}');
      await db.execute('DROP TABLE IF EXISTS attachments');
      await db.execute(
        'DROP TABLE IF EXISTS ${AppConstants.tableProductsLegacy}',
      );
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableCategories}');
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableItemFields}');
      await db.execute('DROP TABLE IF EXISTS ${AppConstants.tableItems}');
      await _onCreate(db, newVersion);
      return;
    }
    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableItemFields} '
        "ADD COLUMN login_title TEXT",
      );
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE ${AppConstants.tableAttachments} '
        'ADD COLUMN aspect_ratio REAL',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // ITEM CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertItem(Item item) async {
    final db = await database;
    return db.insert(
      AppConstants.tableItems,
      item.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableItems,
      orderBy: 'favorite DESC, created_at DESC',
    );
    return maps.map(Item.fromMap).toList();
  }

  Future<Item?> getItemById(int id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableItems,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Item.fromMap(maps.first);
  }

  Future<int> updateItem(Item item) async {
    final db = await database;
    return db.update(
      AppConstants.tableItems,
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    // Cascade via FK — fields and attachments are deleted automatically.
    return db.delete(AppConstants.tableItems, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getItemsCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tableItems}',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Search items by title, tags, and non-PASSWORD field labels/values.
  Future<List<int>> searchItemIds(String query) async {
    final db = await database;
    final q = '%${query.toLowerCase()}%';

    // Items matching title or tags
    final byTitle = await db.rawQuery(
      '''
      SELECT DISTINCT id FROM ${AppConstants.tableItems}
      WHERE LOWER(title) LIKE ? OR LOWER(tags) LIKE ?
    ''',
      [q, q],
    );

    // Items with a matching non-PASSWORD field
    final byField = await db.rawQuery(
      '''
      SELECT DISTINCT item_id as id FROM ${AppConstants.tableItemFields}
      WHERE field_type != 'PASSWORD'
        AND (LOWER(label) LIKE ? OR LOWER(value) LIKE ?)
    ''',
      [q, q],
    );

    final ids = <int>{};
    for (final row in byTitle) {
      ids.add(row['id'] as int);
    }
    for (final row in byField) {
      ids.add(row['id'] as int);
    }
    return ids.toList();
  }

  Future<List<Item>> getItemsByCategory(int categoryId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableItems,
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'favorite DESC, created_at DESC',
    );
    return maps.map(Item.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // FIELD CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertField(ItemField field) async {
    final db = await database;
    return db.insert(
      AppConstants.tableItemFields,
      field.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ItemField>> getFieldsByItemId(int itemId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableItemFields,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'sort_order ASC',
    );
    return maps.map(ItemField.fromMap).toList();
  }

  Future<int> updateField(ItemField field) async {
    final db = await database;
    return db.update(
      AppConstants.tableItemFields,
      field.toMap(),
      where: 'id = ?',
      whereArgs: [field.id],
    );
  }

  Future<int> deleteField(int id) async {
    final db = await database;
    return db.delete(
      AppConstants.tableItemFields,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteFieldsByItemId(int itemId) async {
    final db = await database;
    await db.delete(
      AppConstants.tableItemFields,
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  /// Returns all DATE fields with reminder_enabled = 1 across all items,
  /// used for dashboard stats computation.
  Future<List<ItemField>> getAllReminderDateFields() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableItemFields,
      where: "field_type = 'DATE' AND reminder_enabled = 1",
    );
    return maps.map(ItemField.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // ATTACHMENT CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertAttachment(Attachment attachment) async {
    final db = await database;
    return db.insert(
      AppConstants.tableAttachments,
      attachment.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Attachment>> getAttachmentsByItemId(int itemId) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableAttachments,
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'added_at ASC',
    );
    return maps.map(Attachment.fromMap).toList();
  }

  Future<int> deleteAttachment(int id) async {
    final db = await database;
    return db.delete(
      AppConstants.tableAttachments,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Attachment>> getAllAttachments() async {
    final db = await database;
    final maps = await db.query(AppConstants.tableAttachments);
    return maps.map(Attachment.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // CATEGORY CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final existing = await getCategoryByName(category.name);
    if (existing != null)
      throw Exception('A category with this name already exists');
    return db.insert(
      AppConstants.tableCategories,
      category.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCategories,
      orderBy: 'is_preset DESC, name ASC',
    );
    return maps.map(Category.fromMap).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<Category?> getCategoryByName(String name) async {
    final db = await database;
    final maps = await db.query(
      AppConstants.tableCategories,
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    final existing = await getCategoryById(category.id!);
    if (existing?.isPreset == true) {
      throw Exception('Preset categories cannot be modified');
    }
    final duplicate = await getCategoryByName(category.name);
    if (duplicate != null && duplicate.id != category.id) {
      throw Exception('A category with this name already exists');
    }
    return db.update(
      AppConstants.tableCategories,
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    final category = await getCategoryById(id);
    if (category?.isPreset == true) {
      throw Exception('Preset categories cannot be deleted');
    }
    // Null-out items referencing this category
    await db.update(
      AppConstants.tableItems,
      {'category_id': null},
      where: 'category_id = ?',
      whereArgs: [id],
    );
    return db.delete(
      AppConstants.tableCategories,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getItemCountByCategory(int categoryId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${AppConstants.tableItems} WHERE category_id = ?',
      [categoryId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(AppConstants.tableItemFields);
    await db.delete(AppConstants.tableAttachments);
    await db.delete(AppConstants.tableItems);
  }

  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
