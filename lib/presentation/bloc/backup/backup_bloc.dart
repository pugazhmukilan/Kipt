import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/backup_service.dart';
import '../../../core/utils/preferences_helper.dart';
import 'backup_event.dart';
import 'backup_state.dart';

class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final BackupService backupService;

  BackupBloc({required this.backupService}) : super(BackupInitial()) {
    on<ExportBackup>(_onExportBackup);
    on<ImportBackup>(_onImportBackup);
  }

  Future<void> _onExportBackup(
    ExportBackup event,
    Emitter<BackupState> emit,
  ) async {
    try {
      emit(BackupExporting());

      // Export data to backup archive file
      final backupFilePath = await backupService.exportData();

      // Update last backup date in preferences
      await PreferencesHelper.setLastBackupDate(
        DateTime.now().toIso8601String(),
      );

      emit(BackupExportSuccess(backupFilePath));
    } catch (e) {
      emit(BackupError('Failed to export backup: ${e.toString()}'));
    }
  }

  Future<void> _onImportBackup(
    ImportBackup event,
    Emitter<BackupState> emit,
  ) async {
    try {
      emit(BackupImporting());

      // Import data from backup input
      if (event.backupBytes != null) {
        await backupService.importDataBytes(event.backupBytes!);
      } else if (event.backupPath != null) {
        await backupService.importData(event.backupPath!);
      } else {
        throw Exception('No backup file was selected.');
      }

      emit(const BackupImportSuccess('Data imported successfully'));
    } catch (e) {
      emit(BackupError('Failed to import backup: ${e.toString()}'));
    }
  }
}
