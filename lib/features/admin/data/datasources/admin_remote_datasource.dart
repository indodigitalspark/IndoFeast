import '../../../../models/account_status.dart';
import '../../../../models/admin_models.dart';
import '../../../../services/api/api_client.dart';

class AdminRemoteDataSource {
  const AdminRemoteDataSource();

  Future<AdminDashboardState> fetchDashboard() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/admin/dashboard',
    );
    return AdminDashboardState.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> updateUserStatus({
    required String userId,
    required AccountStatus status,
    String? rejectionReason,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/users/$userId/status',
      data: {'status': status.value, 'rejectionReason': rejectionReason},
    );
  }

  Future<void> createUser({
    required String displayName,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
    required String status,
    String? customRoleKey,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/users',
      data: {
        'displayName': displayName,
        'email': email,
        'phoneNumber': phoneNumber,
        'password': password,
        'role': role,
        'status': status,
        'customRoleKey': customRoleKey,
      },
    );
  }

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? role,
    String? customRoleKey,
    String? status,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/users/$userId/profile',
      data: {
        'displayName': displayName,
        'email': email,
        'phoneNumber': phoneNumber,
        'role': role,
        'customRoleKey': customRoleKey,
        'status': status,
      },
    );
  }

  Future<void> resetUserPassword({
    required String userId,
    required String password,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/users/$userId/password',
      data: {'password': password},
    );
  }

  Future<void> deleteUser(String userId) async {
    await ApiClient.instance.delete<Map<String, dynamic>>(
      '/admin/users/$userId',
    );
  }

  Future<void> updateCommission(double commissionRate) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/commission',
      data: {'commissionRate': commissionRate},
    );
  }

  Future<void> createRole({
    required String name,
    required List<String> permissions,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/roles',
      data: {'name': name, 'permissions': permissions},
    );
  }

  Future<void> updateRole({
    required String key,
    required String name,
    required List<String> permissions,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/roles/$key',
      data: {'name': name, 'permissions': permissions},
    );
  }

  Future<void> createCategory(String name) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/categories',
      data: {'name': name},
    );
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/categories/$categoryId',
      data: {'name': name, 'isActive': isActive},
    );
  }

  Future<void> createBanner({
    required String title,
    required String subtitle,
    required String ctaText,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/banners',
      data: {'title': title, 'subtitle': subtitle, 'ctaText': ctaText},
    );
  }

  Future<void> updateBanner({
    required String bannerId,
    required String title,
    required String subtitle,
    required String ctaText,
    required bool isActive,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/banners/$bannerId',
      data: {
        'title': title,
        'subtitle': subtitle,
        'ctaText': ctaText,
        'isActive': isActive,
      },
    );
  }

  Future<void> updateWebsiteSettings(
    AdminWebsiteSettings websiteSettings,
  ) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/website-settings',
      data: {'websiteSettings': websiteSettings.toMap()},
    );
  }

  Future<void> updateOtpSettings(AdminOtpSettings otpSettings) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/otp-settings',
      data: {'otpSettings': otpSettings.toMap()},
    );
  }

  Future<void> broadcastNotification({
    required String title,
    required String body,
    required List<String> targetRoles,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/notifications/broadcast',
      data: {'title': title, 'body': body, 'targetRoles': targetRoles},
    );
  }

  Future<AdminReportModel> fetchReport({required int days}) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/admin/reports',
      queryParameters: {'days': days},
    );
    return AdminReportModel.fromMap(
      response.data?['report'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<void> createVendorStore({
    required String ownerId,
    required String name,
    required String category,
    required String cuisine,
    required String description,
    required String offerText,
    required int deliveryTime,
    required String priceLevel,
    required double commissionRate,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/admin/vendors/stores',
      data: {
        'ownerId': ownerId,
        'name': name,
        'category': category,
        'cuisine': cuisine,
        'description': description,
        'offerText': offerText,
        'deliveryTime': deliveryTime,
        'priceLevel': priceLevel,
        'commissionRate': commissionRate,
      },
    );
  }

  Future<void> updateVendorStore({
    required String restaurantId,
    required String ownerId,
    required String name,
    required String category,
    required String cuisine,
    required String description,
    required String offerText,
    required int deliveryTime,
    required String priceLevel,
    required double commissionRate,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/admin/vendors/stores/$restaurantId',
      data: {
        'ownerId': ownerId,
        'name': name,
        'category': category,
        'cuisine': cuisine,
        'description': description,
        'offerText': offerText,
        'deliveryTime': deliveryTime,
        'priceLevel': priceLevel,
        'commissionRate': commissionRate,
      },
    );
  }
}
