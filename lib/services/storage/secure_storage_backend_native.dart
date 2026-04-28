import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'secure_storage_backend.dart';

class _NativeSecureStorageBackend implements SecureStorageBackend {
  const _NativeSecureStorageBackend();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}

SecureStorageBackend createStorageBackend() =>
    const _NativeSecureStorageBackend();
