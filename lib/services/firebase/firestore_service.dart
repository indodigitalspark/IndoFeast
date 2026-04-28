import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_initializer.dart';

class FirestoreService {
  const FirestoreService._();

  static FirebaseFirestore? get instance {
    if (!FirebaseInitializer.isInitialized) {
      return null;
    }

    return FirebaseFirestore.instance;
  }
}
