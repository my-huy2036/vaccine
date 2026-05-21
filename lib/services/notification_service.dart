import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Khởi tạo múi giờ (Mặc định Việt Nam)
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (e) {
      debugPrint('Lỗi khởi tạo timezone: $e. Sử dụng UTC làm dự phòng.');
      tz.setLocalLocation(tz.UTC);
    }

    // 2. Cấu hình khởi tạo cho Android & iOS
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 3. Khởi tạo plugin
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Người dùng bấm vào thông báo: ${response.payload}');
      },
    );
  }

  /// Yêu cầu quyền gửi thông báo từ người dùng
  Future<bool> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      final bool? granted = await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
      if (granted == false) return false;
    }

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      final bool? granted = await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (granted == false) return false;
    }

    return true;
  }

  /// Hủy bỏ tất cả thông báo liên quan đến lịch hẹn này
  Future<void> cancelNotifications(String appointmentId) async {
    final int baseId = appointmentId.hashCode.abs();
    // Đã thêm id: vào trước biến
    await _notificationsPlugin.cancel(id: baseId);
    await _notificationsPlugin.cancel(id: baseId + 1);
    await _notificationsPlugin.cancel(id: baseId + 2);
    await _notificationsPlugin.cancel(id: baseId + 3);
  }

  /// Lập lịch thông báo thông minh (4 Trường hợp)
  Future<void> scheduleVaccinationReminders({
    required String appointmentId,
    required String vaccineName,
    required DateTime appointmentDate,
  }) async {
    await requestPermissions();
    await cancelNotifications(appointmentId);

    final int baseId = appointmentId.hashCode.abs();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'vaccination_reminders',
      'Lịch tiêm chủng',
      channelDescription: 'Thông báo nhắc nhở lịch tiêm chủng vaccine',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final DateTime now = DateTime.now();

    // =========================================================================
    // 0. TRƯỜNG HỢP: ĐẶT LỊCH HÔM NAY -> BẮN THÔNG BÁO NGAY LẬP TỨC
    // =========================================================================
    bool isToday = appointmentDate.year == now.year &&
        appointmentDate.month == now.month &&
        appointmentDate.day == now.day;

    if (isToday) {
      // Đã thêm các nhãn id:, title:, body:, notificationDetails:
      await _notificationsPlugin.show(
        id: baseId + 3,
        title: '✅ Đăng ký thành công hôm nay!',
        body: 'Lịch hẹn vắc-xin $vaccineName của bạn diễn ra trong HÔM NAY. Hãy chú ý thời gian nhé.',
        notificationDetails: notificationDetails,
      );
    }

    // =========================================================================
    // 1. Nhắc nhở trước 1 ngày lúc 09:00 Sáng
    // =========================================================================
    final DateTime dayBefore = appointmentDate.subtract(const Duration(days: 1));
    final DateTime scheduleTime1 = DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0);
    if (scheduleTime1.isAfter(now)) {
      // Đã thêm các nhãn và XÓA BỎ uiLocalNotificationDateInterpretation
      await _notificationsPlugin.zonedSchedule(
        id: baseId,
        title: 'Ngày mai có lịch tiêm chủng! 💉',
        body: 'Nhắc nhở: Ngày mai bạn có lịch tiêm vắc-xin $vaccineName. Vui lòng chuẩn bị sức khỏe thật tốt nhé.',
        scheduledDate: tz.TZDateTime.from(scheduleTime1, tz.local),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // =========================================================================
    // 2. Nhắc nhở đúng ngày lúc 07:00 Sáng
    // =========================================================================
    final DateTime scheduleTime2 = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day, 7, 0);
    if (scheduleTime2.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        id: baseId + 1,
        title: 'Hôm nay bạn có lịch tiêm! 📅',
        body: 'Chào buổi sáng! Hôm nay bạn có lịch hẹn tiêm vắc-xin $vaccineName. Hãy mang theo phiếu hẹn nhé.',
        scheduledDate: tz.TZDateTime.from(scheduleTime2, tz.local),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    // =========================================================================
    // 3. Nhắc nhở đúng ngày lúc 13:30 Chiều
    // =========================================================================
    final DateTime scheduleTime3 = DateTime(appointmentDate.year, appointmentDate.month, appointmentDate.day, 13, 30);
    if (scheduleTime3.isAfter(now)) {
      await _notificationsPlugin.zonedSchedule(
        id: baseId + 2,
        title: 'Nhắc nhở lịch tiêm buổi chiều! 📍',
        body: 'Đừng quên lịch tiêm chủng vắc-xin $vaccineName của bạn đang diễn ra trong ngày hôm nay nhé.',
        scheduledDate: tz.TZDateTime.from(scheduleTime3, tz.local),
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}