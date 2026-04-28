import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/delivery_models.dart';
import '../../data/datasources/delivery_remote_datasource.dart';

final deliveryRemoteDataSourceProvider = Provider<DeliveryRemoteDataSource>(
  (ref) => const DeliveryRemoteDataSource(),
);

final deliveryDashboardControllerProvider =
    AsyncNotifierProvider<DeliveryDashboardController, DeliveryDashboardState>(
      DeliveryDashboardController.new,
    );

class DeliveryDashboardController
    extends AsyncNotifier<DeliveryDashboardState> {
  late final DeliveryRemoteDataSource _dataSource;
  StreamSubscription<String>? _dashboardEventsSubscription;

  @override
  Future<DeliveryDashboardState> build() async {
    _dataSource = ref.watch(deliveryRemoteDataSourceProvider);
    ref.onDispose(() => _dashboardEventsSubscription?.cancel());
    final state = await _dataSource.fetchDashboard();
    await _startRealtimeSync();
    return state;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_dataSource.fetchDashboard);
  }

  Future<void> updateAvailability(bool isOnline) async {
    await _mutate(() => _dataSource.updateAvailability(isOnline));
  }

  Future<void> acceptOrder(String orderId) async {
    await _mutate(() => _dataSource.acceptOrder(orderId));
  }

  Future<void> confirmPickup(String orderId) async {
    await _mutate(() => _dataSource.confirmPickup(orderId));
  }

  Future<void> verifyOtp({required String orderId, required String otp}) async {
    await _mutate(() => _dataSource.verifyOtp(orderId: orderId, otp: otp));
  }

  Future<void> updateOrderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    await _mutate(
      () => _dataSource.updateOrderLocation(
        orderId: orderId,
        latitude: latitude,
        longitude: longitude,
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
                  'Delivery API request failed.')
            : 'Delivery API request failed.',
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
