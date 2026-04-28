import 'package:firebase_storage/firebase_storage.dart';

import 'firebase_initializer.dart';

class StorageService {
  const StorageService._();

  static FirebaseStorage? get instance {
    if (!FirebaseInitializer.isInitialized) {
      return null;
    }

    return FirebaseStorage.instance;
  }
}
