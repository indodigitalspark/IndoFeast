import 'dart:async';

import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../models/admin_models.dart';
import '../../../../models/account_status.dart';
import '../../../../models/admin_notification.dart';
import '../../../../models/app_user.dart';
import '../../../../models/user_role.dart';
import '../../../../services/api/api_client.dart';
import '../../../../services/storage/app_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/registration_request.dart';

class FirebaseAuthDataSource {
  FirebaseAuthDataSource();

  Timer? _usersPoller;
  Timer? _pendingUsersPoller;
  Timer? _notificationsPoller;

  Future<void> seedDefaultAdminIfNeeded() async {}

  Future<AuthSession> getCurrentSession() async {
    final token = await AppStorageService.getAuthToken();
    final storedUser = await AppStorageService.getStoredUser();

    if (token == null || token.isEmpty || storedUser == null) {
      return AuthSession.unauthenticated(
        message:
            'Connect the Flutter app to the IndoFeast backend API. Default admin: ${AppConfig.defaultAdminEmail}.',
      );
    }

    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/auth/me',
      );
      final userMap = response.data?['user'] as Map<String, dynamic>?;
      if (userMap == null) {
        await AppStorageService.clearAuthSession();
        return AuthSession.unauthenticated();
      }

      final user = AppUser.fromMap(userMap);
      await AppStorageService.saveAuthSession(token: token, user: user);

      if (!user.canAccessDashboard) {
        await AppStorageService.clearAuthSession();
        return AuthSession.unauthenticated(
          message: _accountStatusMessage(user.status, user.rejectionReason),
        );
      }

      return AuthSession(user: user, isAuthenticated: true);
    } on DioException {
      await AppStorageService.clearAuthSession();
      return AuthSession.unauthenticated(
        message:
            'Backend unavailable. Check that the MongoDB-backed API server is running.',
      );
    }
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
    UserRole? role,
  }) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/login',
        data: <String, dynamic>{
          'email': email,
          'password': password,
          if (role != null) 'role': role.value,
        },
      );

      final token = response.data?['token'] as String?;
      final userMap = response.data?['user'] as Map<String, dynamic>?;
      if (token == null || userMap == null) {
        throw const AppException('Login response was incomplete.');
      }

      final user = AppUser.fromMap(userMap);
      await AppStorageService.saveAuthSession(token: token, user: user);

      return AuthSession(
        user: user,
        isAuthenticated: true,
        message: 'Welcome back, ${user.displayName}.',
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<AuthSession> sendPhoneOtp({
    required String phoneNumber,
    required UserRole role,
  }) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/phone/send-otp',
        data: <String, dynamic>{'phoneNumber': phoneNumber, 'role': role.value},
      );

      final preview = response.data?['otpPreview'] as String?;
      final message =
          response.data?['message'] as String? ??
          'OTP sent to $phoneNumber${preview == null ? '' : '. Demo OTP: $preview'}';

      return AuthSession.unauthenticated(
        message: message,
      ).copyWith(phoneNumber: phoneNumber, isOtpSent: true);
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<AuthSession> verifyPhoneOtp({
    required String otp,
    required UserRole role,
    required String phoneNumber,
  }) async {
    try {
      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/phone/verify-otp',
        data: <String, dynamic>{
          'phoneNumber': phoneNumber,
          'role': role.value,
          'otp': otp,
        },
      );

      final token = response.data?['token'] as String?;
      final userMap = response.data?['user'] as Map<String, dynamic>?;
      if (token == null || userMap == null) {
        throw const AppException('OTP verification response was incomplete.');
      }

      final user = AppUser.fromMap(userMap);
      await AppStorageService.saveAuthSession(token: token, user: user);
      return AuthSession(
        user: user,
        isAuthenticated: true,
        message: 'Phone verification successful.',
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<AuthSession> register(RegistrationRequest request) async {
    try {
      final formDataMap = <String, dynamic>{
        'displayName': request.displayName,
        'email': request.email,
        'phoneNumber': request.phoneNumber,
        'password': request.password,
        'role': request.role.value,
        'otp': request.otp,
        if (request.businessName != null) 'businessName': request.businessName,
        if (request.vehicleLabel != null) 'vehicleLabel': request.vehicleLabel,
      };

      if (request.documentBytes != null && request.documentName != null) {
        formDataMap['document'] = MultipartFile.fromBytes(
          request.documentBytes!,
          filename: request.documentName,
        );
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await ApiClient.instance.post<Map<String, dynamic>>(
        '/auth/register',
        data: formData,
      );

      final token = response.data?['token'] as String?;
      final userMap = response.data?['user'] as Map<String, dynamic>?;
      if (token != null && userMap != null) {
        final user = AppUser.fromMap(userMap);
        await AppStorageService.saveAuthSession(token: token, user: user);
        return AuthSession(
          user: user,
          isAuthenticated: true,
          message:
              response.data?['message'] as String? ??
              'Registration completed successfully.',
        );
      }

      return AuthSession.unauthenticated(
        message:
            response.data?['message'] as String? ??
            'Registration submitted. Your account is pending approval.',
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<AdminWebsiteSettings> fetchPublicWebsiteSettings() async {
    try {
      final response = await ApiClient.instance.get<Map<String, dynamic>>(
        '/auth/public-site',
      );
      return AdminWebsiteSettings.fromMap(
        response.data?['websiteSettings'] as Map<String, dynamic>? ??
            <String, dynamic>{},
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<AuthSession> signOut() async {
    await AppStorageService.clearAuthSession();
    return AuthSession.unauthenticated();
  }

  Stream<List<AppUser>> watchUsers() {
    final controller = StreamController<List<AppUser>>.broadcast();

    Future<void> emitUsers() async {
      try {
        final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/admin/users',
        );
        final items = List<Map<String, dynamic>>.from(
          response.data?['users'] as List? ?? const [],
        );
        controller.add(items.map(AppUser.fromMap).toList(growable: false));
      } catch (_) {
        controller.add(const <AppUser>[]);
      }
    }

    emitUsers();
    _usersPoller?.cancel();
    _usersPoller = Timer.periodic(
      const Duration(seconds: 8),
      (_) => emitUsers(),
    );
    controller.onCancel = () => _usersPoller?.cancel();
    return controller.stream;
  }

  Stream<List<AppUser>> watchPendingUsers() {
    final controller = StreamController<List<AppUser>>.broadcast();

    Future<void> emitUsers() async {
      try {
        final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/admin/users',
          queryParameters: {'status': AccountStatus.pending.value},
        );
        final items = List<Map<String, dynamic>>.from(
          response.data?['users'] as List? ?? const [],
        );
        controller.add(items.map(AppUser.fromMap).toList(growable: false));
      } catch (_) {
        controller.add(const <AppUser>[]);
      }
    }

    emitUsers();
    _pendingUsersPoller?.cancel();
    _pendingUsersPoller = Timer.periodic(
      const Duration(seconds: 8),
      (_) => emitUsers(),
    );
    controller.onCancel = () => _pendingUsersPoller?.cancel();
    return controller.stream;
  }

  Future<void> updateAccountStatus({
    required String userId,
    required AccountStatus status,
    String? rejectionReason,
  }) async {
    try {
      await ApiClient.instance.patch<Map<String, dynamic>>(
        '/admin/users/$userId/status',
        data: <String, dynamic>{
          'status': status.value,
          'rejectionReason': rejectionReason,
        },
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Stream<List<AdminNotification>> watchAdminNotifications() {
    final controller = StreamController<List<AdminNotification>>.broadcast();

    Future<void> emitNotifications() async {
      try {
        final response = await ApiClient.instance.get<Map<String, dynamic>>(
          '/admin/notifications',
        );
        final items = List<Map<String, dynamic>>.from(
          response.data?['notifications'] as List? ?? const [],
        );
        controller.add(
          items
              .map(
                (item) => AdminNotification.fromMap(
                  item['id'] as String? ?? '',
                  item,
                ),
              )
              .toList(growable: false),
        );
      } catch (_) {
        controller.add(const <AdminNotification>[]);
      }
    }

    emitNotifications();
    _notificationsPoller?.cancel();
    _notificationsPoller = Timer.periodic(
      const Duration(seconds: 8),
      (_) => emitNotifications(),
    );
    controller.onCancel = () => _notificationsPoller?.cancel();
    return controller.stream;
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }

    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }

    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach the IndoFeast backend at ${AppConfig.apiBaseUrl}. '
          'Start it with "cd backend && npm run dev" and try again.';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'Login request failed with status $statusCode. '
          'Check the backend deployment logs and API route configuration.';
    }

    return 'Request failed. Check the MongoDB-backed API and try again.';
  }

  String _accountStatusMessage(AccountStatus status, String? rejectionReason) {
    return switch (status) {
      AccountStatus.pending =>
        'Your account is pending approval. An admin has been notified.',
      AccountStatus.rejected =>
        rejectionReason == null || rejectionReason.isEmpty
            ? 'Your account was rejected. Please contact IndoFeast support.'
            : 'Your account was rejected: $rejectionReason',
      AccountStatus.suspended => 'Your account has been suspended.',
      AccountStatus.approved => 'Account approved.',
    };
  }
}
