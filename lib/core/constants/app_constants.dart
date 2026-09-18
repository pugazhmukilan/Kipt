class AppConstants {
  // App Information
  static const String appName = 'Item Vault';
  static const String appVersion = '2.0.0';

  // Database
  static const String databaseName = 'kipt.db';
  static const int databaseVersion = 9;

  // Tables (v8 schema — field-based model with login titles)
  static const String tableItems = 'items';
  static const String tableItemFields = 'item_fields';
  static const String tableAttachments = 'attachments';
  static const String tableCategories = 'categories';

  // Legacy table name (used only in migration DROP)
  static const String tableProductsLegacy = 'products';
  static const String tableNotesLegacy = 'notes';

  // Field Types
  static const String fieldTypeText = 'TEXT';
  static const String fieldTypeDate = 'DATE';
  static const String fieldTypePassword = 'PASSWORD';

  // Preset Categories (simpler, field-agnostic)
  static const List<String> presetCategoryNames = [
    'General',
    'Personal',
    'Finance',
    'Health',
    'Documents',
    'Vehicle',
    'Home',
    'Tech',
    'Other',
  ];

  // Notification Settings
  static const int defaultReminderLeadDays = 30;
  static const String notificationChannelId = 'kipt_reminders';
  static const String notificationChannelName = 'Item Reminders';
  static const String notificationChannelDescription =
      'Notifications for item expiry and date reminders';

  // Shared Preferences Keys
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyDefaultLeadDays = 'default_lead_days';
  static const String prefKeyNotificationEnabled = 'notification_enabled';
  static const String prefKeyLastBackupDate = 'last_backup_date';
  static const String prefKeyOnboardingComplete = 'onboarding_complete';
  static const String prefKeyBiometricEnabled = 'biometric_enabled';
  static const String prefKeyGridColumns = 'grid_columns';
  static const String prefKeySortBy = 'sort_by';

  // Image Settings
  static const int imageCacheWidthThumbnail = 400;
  static const int imageCacheWidthDetail = 1200;
  static const int imageQuality = 85;

  // Backup / Restore
  static const String backupFileName = 'kipt_backup';
  static const String backupDataFileName = 'data.json';
  static const String backupImagesFolder = 'images';

  // Date Formats
  static const String dateFormatDisplay = 'MMM dd, yyyy';
  static const String dateFormatISO = "yyyy-MM-dd";
  static const String dateFormatStorage = 'yyyy-MM-dd';

  // Sort Options
  static const String sortByDateAdded = 'date_added';
  static const String sortByName = 'name';
  static const String sortByCategory = 'category';

  // Password field clipboard clear timeout (seconds)
  static const int clipboardClearSeconds = 45;

  // Password field auto-remask timeout (seconds)
  static const int passwordRemaskSeconds = 20;

  // Fields collapse threshold (detail screen)
  static const int fieldsCollapseThreshold = 5;

  // Quick expiry reminder lead time options (days)
  static const List<int> leadTimeOptions = [7, 30, 60, 90];
}
