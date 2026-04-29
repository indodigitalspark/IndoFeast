import 'package:flutter/foundation.dart';

import 'app_config.dart';
import '../../services/firebase/firebase_initializer.dart';
import '../../services/firebase/notifications_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    if (AppConfig.hasFirebaseConfig) {
      await FirebaseInitializer.initialize();
    }

    if (!kIsWeb && AppConfig.hasFirebaseConfig) {
      await NotificationsService.initialize();
    }
  }
}
