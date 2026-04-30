import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (kIsWeb) return;
    if (_initialized) return;

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> requestPermissions() async {
    if (kIsWeb || _initialized == false) return;
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } else if (!kIsWeb && Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  /// Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = 'playpass_channel',
    String channelName = 'PlayPass',
  }) async {
    if (kIsWeb) return;
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'PlayPass notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails();
    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    await _plugin.show(id, title, body, details);
  }

  /// Schedule subscription expiry notification (3 days before)
  Future<void> scheduleExpiryNotification({
    required String subscriptionId,
    required DateTime endDate,
  }) async {
    if (kIsWeb) return;
    final notifyDate = endDate.subtract(const Duration(days: 3));
    if (notifyDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(notifyDate, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'playpass_expiry',
      'Истечение подписки',
      channelDescription: 'Уведомления об истечении подписки',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      subscriptionId.hashCode,
      '⏰ Подписка скоро истекает',
      'Осталось 3 дня. Продлите подписку чтобы не прерывать игровой прогресс.',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule 1-day-before expiry reminder
  Future<void> scheduleLastDayNotification({
    required String subscriptionId,
    required DateTime endDate,
  }) async {
    if (kIsWeb) return;
    final notifyDate = endDate.subtract(const Duration(days: 1));
    if (notifyDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(notifyDate, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'playpass_expiry',
      'Истечение подписки',
      channelDescription: 'Уведомления об истечении подписки',
      importance: Importance.max,
      priority: Priority.max,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      subscriptionId.hashCode + 1,
      ' Подписка истекает завтра!',
      'Осталось меньше 24 часов. Продлите сейчас!',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Notify when hours balance is low
  Future<void> notifyLowBalance(double hoursLeft) async {
    if (kIsWeb) return;
    if (hoursLeft > 3) return;
    await showNotification(
      id: 9999,
      title: ' Мало часов осталось',
      body: 'Баланс: ${hoursLeft.toStringAsFixed(0)} ч. Пополните подписку!',
    );
  }

  /// Achievement unlocked notification
  Future<void> notifyAchievement(String achievementName) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: ' Новое достижение!',
      body: 'Вы разблокировали: $achievementName',
      channelId: 'playpass_achievements',
      channelName: 'Достижения',
    );
  }

  /// Promo code applied notification
  Future<void> notifyPromoApplied(String bonus) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: ' Промокод активирован!',
      body: 'Получен бонус: $bonus',
      channelId: 'playpass_promo',
      channelName: 'Промокоды',
    );
  }

  /// Booking reminder (30 min before)
  Future<void> scheduleBookingReminder({
    required String bookingId,
    required DateTime bookingTime,
    required String clubName,
  }) async {
    if (kIsWeb) return;
    final notifyDate = bookingTime.subtract(const Duration(minutes: 30));
    if (notifyDate.isBefore(DateTime.now())) return;

    final scheduledDate = tz.TZDateTime.from(notifyDate, tz.local);
    const androidDetails = AndroidNotificationDetails(
      'playpass_booking',
      'Бронирование',
      channelDescription: 'Напоминания о бронировании',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _plugin.zonedSchedule(
      bookingId.hashCode,
      ' Бронь через 30 минут',
      'Не забудьте прийти в $clubName',
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// New banner/promo notification
  Future<void> notifyNewPromo(String title, String description) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: ' $title',
      body: description,
      channelId: 'playpass_promo',
      channelName: 'Акции и новости',
    );
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }

  Future<void> cancel(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }
}
