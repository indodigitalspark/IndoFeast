import 'secure_storage_backend.dart';

class _FallbackStorageBackend implements SecureStorageBackend {
  final Map<String, String> _memory = <String, String>{};

  @override
  Future<void> delete(String key) async {
    _memory.remove(key);
  }

  @override
  Future<String?> read(String key) async => _memory[key];

  @override
  Future<void> write(String key, String value) async {
    _memory[key] = value;
  }
}

SecureStorageBackend createStorageBackend() => _FallbackStorageBackend();
