import '../models/user_role.dart';

class RouteNames {
  const RouteNames._();

  static const login = '/';
  static const customer = '/customer';
  static const vendor = '/vendor';
  static const delivery = '/delivery';
  static const admin = '/admin';
}

extension UserRoleRouting on UserRole {
  String get dashboardRoute => switch (this) {
    UserRole.superAdmin ||
    UserRole.admin ||
    UserRole.manager => RouteNames.admin,
    UserRole.vendor => RouteNames.vendor,
    UserRole.deliveryPartner => RouteNames.delivery,
    UserRole.customer => RouteNames.customer,
  };
}
