// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'secure_storage_backend.dart';

class _WebSecureStorageBackend implements SecureStorageBackend {
  const _WebSecureStorageBackend();

  @override
  Future<void> delete(String key) async {
    html.window.sessionStorage.remove(key);
  }

  @override
  Future<String?> read(String key) async => html.window.sessionStorage[key];

  @override
  Future<void> write(String key, String value) async {
    html.window.sessionStorage[key] = value;
  }
}

SecureStorageBackend createStorageBackend() => const _WebSecureStorageBackend();
