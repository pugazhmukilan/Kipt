import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../bloc/backup/backup_bloc.dart';
import '../bloc/backup/backup_event.dart';
import '../bloc/backup/backup_state.dart';
import '../../core/constants/app_constants.dart';
import '../../core/spacing.dart';
import '../../core/utils/preferences_helper.dart';
import '../widgets/common_widgets.dart';
import '../bloc/theme/theme_cubit.dart';
import '../../data/repositories/auth_service.dart';
import 'about_screen.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _defaultLeadDays = AppConstants.defaultReminderLeadDays;
  String _lastBackupDate = 'Never';
  
  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  void _loadPreferences() {
    setState(() {
      _notificationsEnabled = PreferencesHelper.isNotificationEnabled();
      _defaultLeadDays = PreferencesHelper.getDefaultLeadDays();
      final lastBackup = PreferencesHelper.getLastBackupDate();
      if (lastBackup != null) {
        final date = DateTime.tryParse(lastBackup);
        if (date != null) {
          _lastBackupDate = '${date.day}/${date.month}/${date.year}';
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: BlocListener<BackupBloc, BackupState>(
        listener: (context, state) {
          if (state is BackupExportSuccess) {
            Share.shareXFiles(
              [XFile(state.backupFilePath, mimeType: 'application/octet-stream')],
              subject: 'Kipt Backup',
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Backup created successfully!')),
            );
            
            _loadPreferences();
          }
          
          if (state is BackupImportSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            Navigator.of(context).pop(true); 
          }
          
          if (state is BackupError) {
            final colorScheme = Theme.of(context).colorScheme;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
        child: BlocBuilder<BackupBloc, BackupState>(
          builder: (context, state) {
            final isProcessing = state is BackupExporting || state is BackupImporting;
            
            if (isProcessing) {
              return LoadingIndicator(
                message: state is BackupExporting
                    ? 'Creating backup...'
                    : 'Importing backup...',
              );
            }
            
            return ListView(
              children: [
                _buildSectionHeader('Backup & Restore'),
                Card(
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.cloud_upload_outlined,
                        iconColor: cs.primary,
                        title: 'Export Backup',
                        subtitle: 'Last backup: $_lastBackupDate',
                        onTap: _exportBackup,
                      ),
                      const Divider(height: 1, indent: 72),
                      _SettingTile(
                        icon: Icons.cloud_download_outlined,
                        iconColor: cs.secondary,
                        title: 'Import Backup',
                        subtitle: 'Restore from backup file',
                        onTap: _importBackup,
                      ),
                    ],
                  ),
                ),
                
                _buildSectionHeader('Preferences'),
                Card(
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.category_outlined,
                        iconColor: cs.tertiary,
                        title: 'Manage Categories',
                        subtitle: 'Add, edit, or delete categories',
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const CategoriesScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      _SettingTile(
                        icon: Icons.contrast_outlined,
                        iconColor: cs.primary,
                        title: 'Theme',
                        subtitle: _themeModeLabel(context),
                        onTap: _changeThemeMode,
                      ),
                      const Divider(height: 1, indent: 72),
                      SwitchListTile(
                        secondary: _IconTile(
                          icon: Icons.notifications_outlined,
                          color: cs.tertiary,
                        ),
                        title: const Text('Notifications'),
                        subtitle: const Text('Reminders for expiring dates'),
                        value: _notificationsEnabled,
                        onChanged: (value) {
                          setState(() {
                            _notificationsEnabled = value;
                          });
                          PreferencesHelper.setNotificationEnabled(value);
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      _SettingTile(
                        icon: Icons.timer_outlined,
                        iconColor: cs.secondary,
                        title: 'Default Reminder Lead Time',
                        subtitle: '$_defaultLeadDays days before expiry',
                        onTap: _changeDefaultLeadDays,
                      ),
                    ],
                  ),
                ),
                
                _buildSectionHeader('Security'),
                Card(
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin, vertical: AppSpacing.xs),
                  child: FutureBuilder<bool>(
                    future: AuthService().isAuthenticationAvailable(),
                    builder: (context, snapshot) {
                      final isAvailable = snapshot.data ?? false;

                      return SwitchListTile(
                        secondary: _IconTile(
                          icon: Icons.lock_outline,
                          color: cs.error,
                        ),
                        title: const Text('App Lock'),
                        subtitle: Text(
                          isAvailable
                              ? 'Secure app with biometric or PIN'
                              : 'No device security available. Please set up PIN, pattern, or biometric in device settings.',
                        ),
                        value: AuthService.isAppLockEnabled(),
                        onChanged: isAvailable
                            ? (value) async {
                                if (value) {
                                  final authService = AuthService();
                                  try {
                                    final authenticated = await authService.authenticate();
                                    if (authenticated) {
                                      await AuthService.setAppLock(true);
                                      setState(() {});
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('App lock enabled successfully'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                } else {
                                  await AuthService.setAppLock(false);
                                  setState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('App lock disabled')),
                                    );
                                  }
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
                
                _buildSectionHeader('About'),
                Card(
                  margin: EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin, vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      _SettingTile(
                        icon: Icons.info_outline,
                        iconColor: cs.primary,
                        title: 'App Version',
                        subtitle: AppConstants.appVersion,
                        showChevron: false,
                      ),
                      const Divider(height: 1, indent: 72),
                      _SettingTile(
                        icon: Icons.description_outlined,
                        iconColor: cs.secondary,
                        title: 'About Kipt',
                        subtitle: 'Design, usage tips and privacy',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AboutScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                AppSpacing.xxxl.hBox,
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxxl, AppSpacing.xl, AppSpacing.md),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _themeModeLabel(BuildContext context) {
    final mode = context.watch<ThemeCubit>().state;
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  void _changeThemeMode() {
    final cubit = context.read<ThemeCubit>();
    ThemeMode selected = cubit.state;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Theme'),
              content: RadioGroup<ThemeMode>(
                groupValue: selected,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => selected = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: const Text('System'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: const Text('Light'),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: const Text('Dark'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await cubit.setThemeMode(selected);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _exportBackup() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Export Backup'),
          content: const Text(
            'This will create a backup file with all your items, images, and notes. You can save it to your device or share it.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.read<BackupBloc>().add(ExportBackup());
              },
              child: const Text('Export'),
            ),
          ],
        );
      },
    );
  }
  
  Future<void> _importBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip', 'wvvault', 'json'],
      );
      
      if (result == null) return;

      final selectedPath = result.files.single.path;
      if (selectedPath == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import: file path unavailable')),
        );
        return;
      }
        
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Import Backup'),
            content: const Text(
              'This will replace all your current data with the backup data. This action cannot be undone.\n\nAre you sure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<BackupBloc>().add(ImportBackup(selectedPath));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Import'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: ${e.toString()}')),
      );
    }
  }
  
  void _changeDefaultLeadDays() {
    showDialog(
      context: context,
      builder: (context) {
        int selectedDays = _defaultLeadDays;
        
        return AlertDialog(
          title: const Text('Default Reminder Lead Time'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$selectedDays days'),
                  Slider(
                    value: selectedDays.toDouble(),
                    min: 1,
                    max: 90,
                    divisions: 89,
                    label: '$selectedDays days',
                    onChanged: (value) {
                      setState(() {
                        selectedDays = value.toInt();
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _defaultLeadDays = selectedDays;
                });
                PreferencesHelper.setDefaultLeadDays(selectedDays);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

/// One UI-style settings row: leading icon tile, title, subtitle, chevron.
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.pageMargin, vertical: AppSpacing.xs),
      leading: _IconTile(icon: icon, color: iconColor),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: showChevron
          ? Icon(Icons.chevron_right_rounded, size: 20, color: cs.outline)
          : null,
      onTap: onTap,
    );
  }
}

/// Rounded colored tile behind a settings icon.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconTile({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}
