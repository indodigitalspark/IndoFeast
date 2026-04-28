import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../storage/app_storage_service.dart';

class ApiClient {
  ApiClient._();

  static final Dio instance =
      Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            sendTimeout: const Duration(seconds: 20),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              final token = await AppStorageService.getAuthToken();
              if (token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              options.extra['requestStart'] = DateTime.now();
              AppLogger.debug(
                'API request',
                details: <String, Object?>{
                  'method': options.method,
                  'path': options.path,
                },
              );
              handler.next(options);
            },
            onResponse: (response, handler) {
              final startedAt = response.requestOptions.extra['requestStart'];
              final elapsedMs = startedAt is DateTime
                  ? DateTime.now().difference(startedAt).inMilliseconds
                  : null;

              AppLogger.info(
                'API response',
                details: <String, Object?>{
                  'method': response.requestOptions.method,
                  'path': response.requestOptions.path,
                  'statusCode': response.statusCode,
                  'elapsedMs': elapsedMs,
                },
              );
              handler.next(response);
            },
            onError: (error, handler) {
              AppLogger.error(
                'API error',
                error: error,
                stackTrace: error.stackTrace,
                details: <String, Object?>{
                  'method': error.requestOptions.method,
                  'path': error.requestOptions.path,
                  'statusCode': error.response?.statusCode,
                  'message': error.message,
                },
              );
              handler.next(error);
            },
          ),
        );
}
