import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/vendor_models.dart';
import '../../data/datasources/vendor_remote_datasource.dart';

final vendorRemoteDataSourceProvider = Provider<VendorRemoteDataSource>(
  (ref) => const VendorRemoteDataSource(),
);

final vendorDashboardControllerProvider =
    AsyncNotifierProvider<VendorDashboardController, VendorDashboardState>(
      VendorDashboardController.new,
    );

class VendorDashboardController extends AsyncNotifier<VendorDashboardState> {
  late final VendorRemoteDataSource _dataSource;
  StreamSubscription<String>? _dashboardEventsSubscription;

  @override
  Future<VendorDashboardState> build() async {
    _dataSource = ref.watch(vendorRemoteDataSourceProvider);
    ref.onDispose(() => _dashboardEventsSubscription?.cancel());
    final state = await _dataSource.fetchDashboard();
    await _startRealtimeSync();
    return state;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_dataSource.fetchDashboard);
  }

  Future<void> decideOrder({
    required String orderId,
    required String decision,
  }) async {
    await _mutate(
      () => _dataSource.decideOrder(orderId: orderId, decision: decision),
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await _mutate(
      () => _dataSource.updateOrderStatus(orderId: orderId, status: status),
    );
  }

  Future<void> verifyOrderOtp({
    required String orderId,
    required String otp,
  }) async {
    await _mutate(() => _dataSource.verifyOrderOtp(orderId: orderId, otp: otp));
  }

  Future<void> updateStoreStatus(String storeStatus) async {
    await _mutate(() => _dataSource.updateStoreStatus(storeStatus));
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required String category,
    required int price,
    required int stock,
    required bool isVeg,
    required bool bestseller,
    required bool isAvailable,
    required int discountPercent,
    required int preparationTimeMin,
    required int preparationTimeMax,
    required String addOns,
    required String customizationOptions,
    List<int>? imageBytes,
    String? imageName,
  }) async {
    await _mutate(
      () => _dataSource.createProduct(
        name: name,
        description: description,
        category: category,
        price: price,
        stock: stock,
        isVeg: isVeg,
        bestseller: bestseller,
        isAvailable: isAvailable,
        discountPercent: discountPercent,
        preparationTimeMin: preparationTimeMin,
        preparationTimeMax: preparationTimeMax,
        addOns: addOns,
        customizationOptions: customizationOptions,
        imageBytes: imageBytes,
        imageName: imageName,
      ),
    );
  }

  Future<void> updateProduct({
    required String itemId,
    required String name,
    required String description,
    required String category,
    required int price,
    required int stock,
    required bool isVeg,
    required bool bestseller,
    required bool isAvailable,
    required int discountPercent,
    required int preparationTimeMin,
    required int preparationTimeMax,
    required String addOns,
    required String customizationOptions,
    List<int>? imageBytes,
    String? imageName,
  }) async {
    await _mutate(
      () => _dataSource.updateProduct(
        itemId: itemId,
        name: name,
        description: description,
        category: category,
        price: price,
        stock: stock,
        isVeg: isVeg,
        bestseller: bestseller,
        isAvailable: isAvailable,
        discountPercent: discountPercent,
        preparationTimeMin: preparationTimeMin,
        preparationTimeMax: preparationTimeMax,
        addOns: addOns,
        customizationOptions: customizationOptions,
        imageBytes: imageBytes,
        imageName: imageName,
      ),
    );
  }

  Future<void> deleteProduct(String itemId) async {
    await _mutate(() => _dataSource.deleteProduct(itemId));
  }

  Future<void> updateStock({
    required String itemId,
    required int stock,
    required bool isAvailable,
  }) async {
    await _mutate(
      () => _dataSource.updateStock(
        itemId: itemId,
        stock: stock,
        isAvailable: isAvailable,
      ),
    );
  }

  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      state = const AsyncLoading();
      state = await AsyncValue.guard(_dataSource.fetchDashboard);
    } on DioException catch (error) {
      throw AppException(
        error.response?.data is Map<String, dynamic>
            ? ((error.response?.data as Map<String, dynamic>)['message']
                      as String? ??
                  'Vendor API request failed.')
            : 'Vendor API request failed.',
      );
    }
  }

  Future<void> _startRealtimeSync() async {
    await _dashboardEventsSubscription?.cancel();
    final stream = await _dataSource.watchDashboardEvents();
    _dashboardEventsSubscription = stream.listen((_) async {
      try {
        final next = await _dataSource.fetchDashboard();
        state = AsyncData(next);
      } catch (_) {}
    });
  }
}
