import 'secure_storage_backend_stub.dart'
    if (dart.library.html) 'secure_storage_backend_web.dart'
    if (dart.library.io) 'secure_storage_backend_native.dart';

abstract class SecureStorageBackend {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

SecureStorageBackend createSecureStorageBackend() => createStorageBackend();
