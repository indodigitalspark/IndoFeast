import 'dart:convert';
import 'dart:developer' as developer;

enum AppLogLevel { debug, info, warning, error }

class AppLogger {
  const AppLogger._();

  static void debug(
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _log(AppLogLevel.debug, message, details: details);
  }

  static void info(
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _log(AppLogLevel.info, message, details: details);
  }

  static void warning(
    String message, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _log(AppLogLevel.warning, message, details: details);
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _log(
      AppLogLevel.error,
      message,
      error: error,
      stackTrace: stackTrace,
      details: details,
    );
  }

  static void _log(
    AppLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    developer.log(
      message,
      name: 'IndoFeast',
      level: switch (level) {
        AppLogLevel.debug => 500,
        AppLogLevel.info => 800,
        AppLogLevel.warning => 900,
        AppLogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
      zone: null,
      time: DateTime.now(),
      sequenceNumber: null,
    );

    if (details.isNotEmpty) {
      developer.log(
        jsonEncode(details),
        name: 'IndoFeast.details',
        level: 800,
        time: DateTime.now(),
      );
    }
  }
}
