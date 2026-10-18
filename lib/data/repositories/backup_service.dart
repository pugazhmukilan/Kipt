import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/constants/app_constants.dart';
import '../models/category.dart';
import '../models/item.dart';
import '../models/item_field.dart';
import 'item_repository.dart';
import 'image_storage_service.dart';

class BackupService {
  final ItemRepository itemRepository;
  final ImageStorageService imageStorageService;

  BackupService({
    required this.itemRepository,
    required this.imageStorageService,
  });

  /// Export all data to a ZIP file
  Future<String> exportData() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final backupDir = Directory(path.join(tempDir.path, 'backup_temp'));

      if (await backupDir.exists()) {
        await backupDir.delete(recursive: true);
      }
      await backupDir.create(recursive: true);

      final itemsWithDetails = await itemRepository.getAllItemsWithDetails();
      final categories = await itemRepository.getAllCategories();

      // We do not export PASSWORD fields per spec §6
      final List<Map<String, dynamic>> itemsList = [];
      for (final iwd in itemsWithDetails) {
        final itemMap = iwd.item.toMap();

        final List<Map<String, dynamic>> fields = [];
        for (final f in iwd.fields) {
          if (f.fieldType == FieldType.password) continue;
          fields.add(f.toMap());
        }
        itemMap['fields'] = fields;
        itemMap['attachments'] = iwd.attachments.map((a) => a.toMap()).toList();

        itemsList.add(itemMap);
      }

      final Map<String, dynamic> backupData = {
        'version': AppConstants.appVersion,
        'schema_version': 7,
        'exported_at': DateTime.now().toIso8601String(),
        'categories': categories.map((c) => c.toMap()).toList(),
        'items': itemsList,
      };

      final jsonFile = File(
        path.join(backupDir.path, AppConstants.backupDataFileName),
      );
      await jsonFile.writeAsString(jsonEncode(backupData));

      final imagesBackupDir = Directory(
        path.join(backupDir.path, AppConstants.backupImagesFolder),
      );
      await imagesBackupDir.create(recursive: true);

      for (final iwd in itemsWithDetails) {
        for (final attachment in iwd.attachments) {
          final file = File(attachment.path);
          if (await file.exists()) {
            final fileName = path.basename(attachment.path);
            final destPath = path.join(imagesBackupDir.path, fileName);
            await file.copy(destPath);
          }
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFileName =
          '${AppConstants.backupFileName}_$timestamp${AppConstants.backupFileExtension}';
      final zipFilePath = path.join(tempDir.path, zipFileName);

      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      await encoder.addDirectory(backupDir, includeDirName: false);
      encoder.close();

      await backupDir.delete(recursive: true);

      return zipFilePath;
    } catch (e) {
      throw Exception('Failed to export data: ${e.toString()}');
    }
  }

  /// Import data from a ZIP file
  Future<void> importData(String zipFilePath) async {
    final bytes = await File(zipFilePath).readAsBytes();
    await _importDataBytes(bytes);
  }

  /// Import a ZIP selected through a platform file provider.
  Future<void> importDataBytes(List<int> bytes) async {
    await _importDataBytes(bytes);
  }

  Future<void> _importDataBytes(List<int> bytes) async {
    Directory? extractDir;
    try {
      final tempDir = await getTemporaryDirectory();
      extractDir = Directory(path.join(tempDir.path, 'backup_extract'));

      if (await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
      await extractDir.create(recursive: true);

      if (!_isZipArchive(bytes)) {
        throw Exception('Invalid backup file: expected a ZIP archive.');
      }
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        final extractedPath = _safeExtractPath(extractDir, filename);
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File(extractedPath);
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);
        } else {
          await Directory(extractedPath).create(recursive: true);
        }
      }

      File? jsonFile;
      Directory? rootBackupDir;

      final rootDataFile = File(
        path.join(extractDir.path, AppConstants.backupDataFileName),
      );
      if (await rootDataFile.exists()) {
        jsonFile = rootDataFile;
        rootBackupDir = extractDir;
      } else {
        final entities = await extractDir.list().toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final subDataFile = File(
              path.join(entity.path, AppConstants.backupDataFileName),
            );
            if (await subDataFile.exists()) {
              jsonFile = subDataFile;
              rootBackupDir = entity;
              break;
            }
          }
        }
      }

      if (jsonFile == null || rootBackupDir == null) {
        throw Exception('Invalid backup file: data.json not found');
      }

      final jsonContent = await jsonFile.readAsString();
      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Invalid backup file: data.json must contain an object.',
        );
      }
      final Map<String, dynamic> backupData = decoded;

      if (backupData['schema_version'] != 7) {
        throw Exception(
          'Incompatible backup version. Only v7 schema backups are supported.',
        );
      }

      // 1. Categories
      final List<dynamic> categoriesJson = backupData['categories'] ?? [];
      final Map<int, int> categoryIdMap = {}; // old -> new
      final existingCategories = await itemRepository.getAllCategories();
      final categoryIdsByName = <String, int>{
        for (final category in existingCategories)
          if (category.id != null) category.name: category.id!,
      };
      for (final catMap in categoriesJson) {
        final cat = Category.fromMap(catMap as Map<String, dynamic>);
        final oldId = cat.id;
        final newId =
            categoryIdsByName[cat.name] ??
            await itemRepository.createCategory(cat.copyWith(id: null));
        categoryIdsByName[cat.name] = newId;
        if (oldId != null) categoryIdMap[oldId] = newId;
      }

      // 2. Items
      final List<dynamic> itemsJson = backupData['items'] ?? [];
      final imagesBackupDir = Directory(
        path.join(rootBackupDir.path, AppConstants.backupImagesFolder),
      );

      for (final itemMap in itemsJson) {
        final map = itemMap as Map<String, dynamic>;

        final item = Item.fromMap(map);
        final oldCatId = item.categoryId;
        final newCatId = oldCatId != null ? categoryIdMap[oldCatId] : null;

        final fields = (map['fields'] as List<dynamic>? ?? [])
            .map(
              (e) => ItemField.fromMap(
                e as Map<String, dynamic>,
              ).copyWith(id: null),
            )
            .toList();

        // Process attachments
        final List<String> newAttachmentPaths = [];
        final oldAttachments = (map['attachments'] as List<dynamic>? ?? []);
        for (final attMap in oldAttachments) {
          final oldPath = attMap['path'] as String;
          final fileName = path.basename(oldPath);
          final sourceFile = File(path.join(imagesBackupDir.path, fileName));

          if (await sourceFile.exists()) {
            newAttachmentPaths.add(sourceFile.path);
          }
        }

        await itemRepository.createItem(
          item: item.copyWith(id: null, categoryId: newCatId),
          fields: fields,
          attachmentPaths: newAttachmentPaths,
        );
      }
    } catch (e) {
      throw Exception('Failed to import data: ${e.toString()}');
    } finally {
      if (extractDir != null && await extractDir.exists()) {
        await extractDir.delete(recursive: true);
      }
    }
  }

  bool _isZipArchive(List<int> bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4b &&
        ((bytes[2] == 0x03 && bytes[3] == 0x04) ||
            (bytes[2] == 0x05 && bytes[3] == 0x06) ||
            (bytes[2] == 0x07 && bytes[3] == 0x08));
  }

  String _safeExtractPath(Directory extractDir, String archiveName) {
    final rootPath = path.normalize(extractDir.path);
    final extractedPath = path.normalize(path.join(rootPath, archiveName));
    final relativePath = path.relative(extractedPath, from: rootPath);

    if (path.isAbsolute(relativePath) ||
        relativePath == '..' ||
        relativePath.startsWith('..${path.separator}')) {
      throw Exception('Invalid backup file: unsafe archive entry.');
    }

    return extractedPath;
  }
}
