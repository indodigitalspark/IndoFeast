import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'firebase_initializer.dart';

class NotificationsService {
  const NotificationsService._();

  static Future<void> initialize() async {
    if (!FirebaseInitializer.isInitialized || kIsWeb) {
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
  }
}
