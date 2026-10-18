import 'package:equatable/equatable.dart';

abstract class BackupEvent extends Equatable {
  const BackupEvent();

  @override
  List<Object?> get props => [];
}

/// Export data to backup file
class ExportBackup extends BackupEvent {}

/// Import data from backup file
class ImportBackup extends BackupEvent {
  final String? backupPath;
  final List<int>? backupBytes;

  const ImportBackup(this.backupPath) : backupBytes = null;

  const ImportBackup.bytes(this.backupBytes) : backupPath = null;

  @override
  List<Object?> get props => [backupPath, backupBytes];
}
