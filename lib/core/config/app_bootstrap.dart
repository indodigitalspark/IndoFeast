import 'package:flutter/foundation.dart';

import '../../features/auth/data/datasources/firebase_auth_datasource.dart';
import 'app_config.dart';
import '../../services/firebase/firebase_initializer.dart';
import '../../services/firebase/notifications_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<void> initialize() async {
    if (AppConfig.hasFirebaseConfig) {
      await FirebaseInitializer.initialize();
    }
    await FirebaseAuthDataSource().seedDefaultAdminIfNeeded();

    if (!kIsWeb && AppConfig.hasFirebaseConfig) {
      await NotificationsService.initialize();
    }
  }
}
