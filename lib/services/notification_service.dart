// ignore_for_file: avoid_print

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui'; // Necesario para el color

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // Configuración de Android (Icono silueta)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('logo_noti');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Pedir permiso en Android 13+
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }
  }

  // --- MOSTRAR AHORA (La única que necesitamos) ---
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'channel_dental_lanch_basic',
            'Notificaciones Generales',
            importance: Importance.max,
            priority: Priority.high,
            icon: 'logo_noti',
            largeIcon: DrawableResourceAndroidBitmap('logo_color'),
            color: Color(0xFFE91E63),
            playSound: true,
            enableVibration: true,
          );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _notificationsPlugin.show(id, title, body, details);
    } catch (e) {
      print("❌ Error mostrando notificación: $e");
    }
  }
}
