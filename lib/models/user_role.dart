enum UserRole {
  superAdmin('SUPER_ADMIN'),
  admin('ADMIN'),
  manager('MANAGER'),
  vendor('VENDOR'),
  deliveryPartner('DELIVERY_PARTNER'),
  customer('CUSTOMER');

  const UserRole(this.value);

  final String value;

  bool get isAdminFamily => switch (this) {
    UserRole.superAdmin || UserRole.admin || UserRole.manager => true,
    _ => false,
  };

  String get label => switch (this) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.manager => 'Manager',
    UserRole.admin => 'Admin',
    UserRole.deliveryPartner => 'Delivery Partner',
    UserRole.vendor => 'Vendor (Store)',
    UserRole.customer => 'Customer',
  };

  String get portalTitle => switch (this) {
    UserRole.superAdmin => 'Super Admin Portal',
    UserRole.manager => 'Manager Portal',
    UserRole.admin => 'Admin Portal',
    UserRole.deliveryPartner => 'Delivery Partner Portal',
    UserRole.vendor => 'Vendor Store Portal',
    UserRole.customer => 'Customer Portal',
  };

  String get portalDescription => switch (this) {
    UserRole.superAdmin =>
      'Full platform control, approvals, reports, finance, and role management.',
    UserRole.manager =>
      'Team operations, daily monitoring, approvals, and business reporting.',
    UserRole.admin =>
      'Platform operations, user management, settlements, and escalations.',
    UserRole.deliveryPartner =>
      'Pickup assignments, live delivery updates, route work, and earnings.',
    UserRole.vendor =>
      'Store operations, menu management, order handling, and earnings.',
    UserRole.customer =>
      'Browse restaurants, place orders, track deliveries, and manage wallet.',
  };

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}
