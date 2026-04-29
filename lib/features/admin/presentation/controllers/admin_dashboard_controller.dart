import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/account_status.dart';
import '../../../../models/admin_models.dart';
import '../../data/datasources/admin_remote_datasource.dart';

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>(
  (ref) => const AdminRemoteDataSource(),
);

final adminDashboardControllerProvider =
    AsyncNotifierProvider<AdminDashboardController, AdminDashboardState>(
      AdminDashboardController.new,
    );

class AdminDashboardController extends AsyncNotifier<AdminDashboardState> {
  late final AdminRemoteDataSource _dataSource;

  @override
  Future<AdminDashboardState> build() async {
    _dataSource = ref.watch(adminRemoteDataSourceProvider);
    return _dataSource.fetchDashboard();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_dataSource.fetchDashboard);
  }

  Future<void> approveUser(String userId) async {
    await _mutate(
      () => _dataSource.updateUserStatus(
        userId: userId,
        status: AccountStatus.approved,
      ),
    );
  }

  Future<void> rejectUser(String userId, {String? reason}) async {
    await _mutate(
      () => _dataSource.updateUserStatus(
        userId: userId,
        status: AccountStatus.rejected,
        rejectionReason: reason,
      ),
    );
  }

  Future<void> suspendUser(String userId) async {
    await _mutate(
      () => _dataSource.updateUserStatus(
        userId: userId,
        status: AccountStatus.suspended,
      ),
    );
  }

  Future<void> reactivateUser(String userId) async {
    await _mutate(
      () => _dataSource.updateUserStatus(
        userId: userId,
        status: AccountStatus.approved,
      ),
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
    await _mutate(
      () => _dataSource.createUser(
        displayName: displayName,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        role: role,
        status: status,
        customRoleKey: customRoleKey,
      ),
    );
  }

  Future<void> assignCustomRole({
    required String userId,
    required String role,
    String? customRoleKey,
  }) async {
    await _mutate(
      () => _dataSource.updateUserProfile(
        userId: userId,
        role: role,
        customRoleKey: customRoleKey,
      ),
    );
  }

  Future<void> updateUserProfile({
    required String userId,
    required String displayName,
    required String email,
    required String phoneNumber,
    required String role,
    required String status,
    String? customRoleKey,
  }) async {
    await _mutate(
      () => _dataSource.updateUserProfile(
        userId: userId,
        displayName: displayName,
        email: email,
        phoneNumber: phoneNumber,
        role: role,
        customRoleKey: customRoleKey,
        status: status,
      ),
    );
  }

  Future<void> deleteUser(String userId) async {
    await _mutate(() => _dataSource.deleteUser(userId));
  }

  Future<void> updateCommission(double commissionRate) async {
    await _mutate(() => _dataSource.updateCommission(commissionRate));
  }

  Future<void> createRole({
    required String name,
    required List<String> permissions,
  }) async {
    await _mutate(
      () => _dataSource.createRole(name: name, permissions: permissions),
    );
  }

  Future<void> updateRole({
    required String key,
    required String name,
    required List<String> permissions,
  }) async {
    await _mutate(
      () => _dataSource.updateRole(
        key: key,
        name: name,
        permissions: permissions,
      ),
    );
  }

  Future<void> createCategory(String name) async {
    await _mutate(() => _dataSource.createCategory(name));
  }

  Future<void> updateCategory({
    required String categoryId,
    required String name,
    required bool isActive,
  }) async {
    await _mutate(
      () => _dataSource.updateCategory(
        categoryId: categoryId,
        name: name,
        isActive: isActive,
      ),
    );
  }

  Future<void> createBanner({
    required String title,
    required String subtitle,
    required String ctaText,
  }) async {
    await _mutate(
      () => _dataSource.createBanner(
        title: title,
        subtitle: subtitle,
        ctaText: ctaText,
      ),
    );
  }

  Future<void> updateBanner({
    required String bannerId,
    required String title,
    required String subtitle,
    required String ctaText,
    required bool isActive,
  }) async {
    await _mutate(
      () => _dataSource.updateBanner(
        bannerId: bannerId,
        title: title,
        subtitle: subtitle,
        ctaText: ctaText,
        isActive: isActive,
      ),
    );
  }

  Future<void> broadcastNotification({
    required String title,
    required String body,
    required List<String> targetRoles,
  }) async {
    await _mutate(
      () => _dataSource.broadcastNotification(
        title: title,
        body: body,
        targetRoles: targetRoles,
      ),
    );
  }

  Future<void> updateWebsiteSettings(
    AdminWebsiteSettings websiteSettings,
  ) async {
    await _mutate(() => _dataSource.updateWebsiteSettings(websiteSettings));
  }

  Future<void> updateOtpSettings(AdminOtpSettings otpSettings) async {
    await _mutate(() => _dataSource.updateOtpSettings(otpSettings));
  }

  Future<void> resetUserPassword({
    required String userId,
    required String password,
  }) async {
    await _mutate(
      () => _dataSource.resetUserPassword(userId: userId, password: password),
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
    await _mutate(
      () => _dataSource.createVendorStore(
        ownerId: ownerId,
        name: name,
        category: category,
        cuisine: cuisine,
        description: description,
        offerText: offerText,
        deliveryTime: deliveryTime,
        priceLevel: priceLevel,
        commissionRate: commissionRate,
      ),
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
    await _mutate(
      () => _dataSource.updateVendorStore(
        restaurantId: restaurantId,
        ownerId: ownerId,
        name: name,
        category: category,
        cuisine: cuisine,
        description: description,
        offerText: offerText,
        deliveryTime: deliveryTime,
        priceLevel: priceLevel,
        commissionRate: commissionRate,
      ),
    );
  }

  Future<void> generateReport(int days) async {
    final current = state.valueOrNull;
    if (current == null) {
      await refresh();
      return;
    }

    try {
      final report = await _dataSource.fetchReport(days: days);
      state = AsyncData(
        AdminDashboardState(
          analytics: current.analytics,
          users: current.users,
          restaurants: current.restaurants,
          transactions: current.transactions,
          notifications: current.notifications,
          config: current.config,
          report: report,
        ),
      );
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      state = const AsyncLoading();
      state = await AsyncValue.guard(_dataSource.fetchDashboard);
    } on DioException catch (error) {
      throw AppException(_extractMessage(error));
    }
  }

  String _extractMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) {
      return data['message'] as String;
    }
    return 'Admin API request failed.';
  }
}
