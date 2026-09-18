import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../core/constants/app_constants.dart';
import '../models/item_field.dart';

class NotificationService {
  static NotificationService? _instance;
  final FlutterLocalNotificationsPlugin _plugin;

  NotificationService._() : _plugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() {
    _instance ??= NotificationService._();
    return _instance!;
  }

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    await _createNotificationChannel();
  }

  Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  void _onNotificationTapped(NotificationResponse response) {
    // payload = 'item:{itemId}' — handled at app level if needed
  }

  // ---------------------------------------------------------------------------
  // Field-based reminders (spec §3.2, §3.4, §4)
  // ---------------------------------------------------------------------------

  /// Schedule a reminder for a DATE field.
  /// The notification fires [field.reminderLeadDays] (or [defaultLeadDays]) 
  /// before [field.parsedDate]. Uses [field.id] as the notification ID so it
  /// can be precisely cancelled later.
  Future<void> scheduleFieldReminder(
    ItemField field,
    String itemTitle, {
    int defaultLeadDays = AppConstants.defaultReminderLeadDays,
  }) async {
    if (!field.reminderEnabled) return;
    if (field.fieldType != FieldType.date) return;
    final date = field.parsedDate;
    if (date == null) return;

    final leadDays = field.reminderLeadDays ?? defaultLeadDays;
    final notifyAt = date.subtract(Duration(days: leadDays));

    if (notifyAt.isBefore(DateTime.now())) return; // already in the past

    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);
    final notifId = _notifIdForField(field.id!);

    final body = leadDays == 0
        ? '"${field.label}" for $itemTitle is due today'
        : '"${field.label}" for $itemTitle expires in $leadDays day${leadDays == 1 ? '' : 's'}';

    await _plugin.zonedSchedule(
      notifId,
      'Item Reminder — $itemTitle',
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: 'item:${field.itemId}',
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel the reminder notification for a specific field.
  Future<void> cancelFieldReminder(int fieldId) async {
    await _plugin.cancel(_notifIdForField(fieldId));
  }

  /// Cancel reminders for a list of fields (when deleting an item).
  Future<void> cancelFieldReminders(List<ItemField> fields) async {
    for (final f in fields) {
      if (f.id != null && f.fieldType == FieldType.date && f.reminderEnabled) {
        await cancelFieldReminder(f.id!);
      }
    }
  }

  /// Reschedule a field reminder (cancel old, schedule new).
  Future<void> rescheduleFieldReminder(
    ItemField field,
    String itemTitle, {
    int defaultLeadDays = AppConstants.defaultReminderLeadDays,
  }) async {
    if (field.id != null) await cancelFieldReminder(field.id!);
    await scheduleFieldReminder(field, itemTitle,
        defaultLeadDays: defaultLeadDays);
  }

  Future<void> cancelAllNotifications() async => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> getPendingNotifications() async =>
      _plugin.pendingNotificationRequests();

  Future<bool> requestPermissions() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    return result ?? true;
  }

  /// Maps a field ID to a stable notification ID (stays within 32-bit int range).
  int _notifIdForField(int fieldId) => fieldId % 2147483647;
}
