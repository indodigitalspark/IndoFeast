import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';

class FirebaseInitializer {
  const FirebaseInitializer._();

  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized || Firebase.apps.isNotEmpty) {
      _isInitialized = true;
      return;
    }

    if (!AppConfig.hasFirebaseConfig) {
      return;
    }

    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: AppConfig.firebaseApiKey,
        appId: AppConfig.firebaseAppId,
        messagingSenderId: AppConfig.firebaseMessagingSenderId,
        projectId: AppConfig.firebaseProjectId,
        authDomain: AppConfig.firebaseAuthDomain.isEmpty
            ? null
            : AppConfig.firebaseAuthDomain,
        storageBucket: AppConfig.firebaseStorageBucket.isEmpty
            ? null
            : AppConfig.firebaseStorageBucket,
        measurementId: kIsWeb && AppConfig.firebaseMeasurementId.isNotEmpty
            ? AppConfig.firebaseMeasurementId
            : null,
      ),
    );

    _isInitialized = true;
  }
}
