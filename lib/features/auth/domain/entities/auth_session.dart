import '../../../../models/app_user.dart';

class AuthSession {
  const AuthSession({
    required this.user,
    required this.isAuthenticated,
    this.message,
    this.phoneNumber,
    this.isOtpSent = false,
  });

  final AppUser? user;
  final bool isAuthenticated;
  final String? message;
  final String? phoneNumber;
  final bool isOtpSent;

  bool get canAccessDashboard => user?.canAccessDashboard ?? false;

  AuthSession copyWith({
    AppUser? user,
    bool? isAuthenticated,
    String? message,
    String? phoneNumber,
    bool? isOtpSent,
    bool clearMessage = false,
  }) {
    return AuthSession(
      user: user ?? this.user,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      message: clearMessage ? null : message ?? this.message,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isOtpSent: isOtpSent ?? this.isOtpSent,
    );
  }

  factory AuthSession.unauthenticated({String? message}) {
    return AuthSession(user: null, isAuthenticated: false, message: message);
  }
}
