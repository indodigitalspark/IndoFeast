import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../models/customer_models.dart';
import '../../data/datasources/customer_remote_datasource.dart';

final customerRemoteDataSourceProvider = Provider<CustomerRemoteDataSource>(
  (ref) => const CustomerRemoteDataSource(),
);

final customerDashboardControllerProvider =
    AsyncNotifierProvider<CustomerDashboardController, CustomerDashboardState>(
      CustomerDashboardController.new,
    );

class CustomerDashboardController
    extends AsyncNotifier<CustomerDashboardState> {
  late final CustomerRemoteDataSource _dataSource;
  StreamSubscription<String>? _orderEventsSubscription;

  @override
  Future<CustomerDashboardState> build() async {
    _dataSource = ref.watch(customerRemoteDataSourceProvider);
    ref.onDispose(() => _orderEventsSubscription?.cancel());
    final state = await _loadDashboard(CustomerDashboardState.initial());
    await _startRealtimeSync();
    return state;
  }

  Future<void> refresh() async {
    final current = state.valueOrNull ?? CustomerDashboardState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> updateSearch(String value) async {
    final current = (state.valueOrNull ?? CustomerDashboardState.initial())
        .copyWith(search: value);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> updateCategory(String value) async {
    final current = (state.valueOrNull ?? CustomerDashboardState.initial())
        .copyWith(selectedCategory: value);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> updateRating(double? value) async {
    final current = (state.valueOrNull ?? CustomerDashboardState.initial())
        .copyWith(minRating: value, clearRating: value == null);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> updateDeliveryTime(int? value) async {
    final current = (state.valueOrNull ?? CustomerDashboardState.initial())
        .copyWith(maxDeliveryTime: value, clearDeliveryTime: value == null);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> updatePriceFilter(String? value) async {
    final current = (state.valueOrNull ?? CustomerDashboardState.initial())
        .copyWith(priceFilter: value, clearPrice: value == null);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadDashboard(current));
  }

  Future<void> addToCart({
    required String restaurantId,
    required String menuItemId,
  }) async {
    await _mutate((current) async {
      final cart = await _dataSource.addToCart(
        restaurantId: restaurantId,
        menuItemId: menuItemId,
      );
      return current.copyWith(cart: cart);
    });
  }

  Future<void> removeFromCart({
    required String restaurantId,
    required String menuItemId,
    bool removeCompletely = false,
  }) async {
    await _mutate((current) async {
      final cart = await _dataSource.updateCartItem(
        restaurantId: restaurantId,
        menuItemId: menuItemId,
        action: removeCompletely ? 'remove' : 'decrement',
      );
      return current.copyWith(cart: cart);
    });
  }

  Future<void> applyCoupon(String? code) async {
    await _mutate((current) async {
      final cart = await _dataSource.applyCoupon(code);
      return current.copyWith(cart: cart);
    });
  }

  Future<void> updateOrderMode(String orderMode) async {
    await _mutate((current) async {
      final cart = await _dataSource.updateOrderMode(orderMode);
      return current.copyWith(cart: cart);
    });
  }

  Future<void> updatePaymentMethod(String paymentMethod) async {
    await _mutate((current) async {
      final cart = await _dataSource.updatePaymentMethod(paymentMethod);
      return current.copyWith(cart: cart);
    });
  }

  Future<CustomerCheckoutModel> placeOrder() async {
    final current = state.valueOrNull ?? CustomerDashboardState.initial();
    state = const AsyncLoading();
    try {
      final checkout = await _dataSource.placeOrder(current.cart.paymentMethod);
      final next = await _loadDashboard(current);
      state = AsyncData(next);
      return checkout;
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? ((error.response?.data as Map<String, dynamic>)['message']
                    as String? ??
                'Customer API request failed.')
          : 'Customer API request failed.';
      state = AsyncError(AppException(message), StackTrace.current);
      throw AppException(message);
    }
  }

  Future<void> cancelOrder(String orderId) async {
    await _mutate((current) async {
      await _dataSource.cancelOrder(orderId);
      return _loadDashboard(current);
    });
  }

  Future<CustomerOrderModel> verifyPayment({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    final order = await _dataSource.verifyPayment(
      orderId: orderId,
      payload: payload,
    );
    final current = state.valueOrNull ?? CustomerDashboardState.initial();
    state = AsyncData(await _loadDashboard(current));
    return order;
  }

  Future<void> addFunds(int amount) async {
    await _mutate((current) async {
      final wallet = await _dataSource.addWalletFunds(amount);
      return current.copyWith(wallet: wallet);
    });
  }

  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    await _mutate((current) async {
      await _dataSource.submitReview(
        orderId: orderId,
        rating: rating,
        comment: comment,
      );
      return _loadDashboard(current);
    });
  }

  Future<CustomerDashboardState> _loadDashboard(
    CustomerDashboardState current,
  ) async {
    try {
      final results = await Future.wait<dynamic>([
        _dataSource.fetchHome(
          search: current.search,
          category: current.selectedCategory,
          minRating: current.minRating,
          maxDeliveryTime: current.maxDeliveryTime,
          priceFilter: current.priceFilter,
        ),
        _dataSource.fetchCart(),
        _dataSource.fetchActiveOrders(),
        _dataSource.fetchOrderHistory(),
        _dataSource.fetchWallet(),
      ]);

      final home = results[0] as Map<String, dynamic>;
      return current.copyWith(
        banners: List<Map<String, dynamic>>.from(
          home['banners'] as List? ?? const [],
        ).map(OfferBannerModel.fromMap).toList(growable: false),
        categories: List<String>.from(
          home['categories'] as List? ?? const ['All'],
        ),
        coupons: List<Map<String, dynamic>>.from(
          home['coupons'] as List? ?? const [],
        ).map(CouponModelView.fromMap).toList(growable: false),
        restaurants: List<Map<String, dynamic>>.from(
          home['restaurants'] as List? ?? const [],
        ).map(RestaurantModelView.fromMap).toList(growable: false),
        cart: results[1] as CustomerCartModel,
        activeOrders: results[2] as List<CustomerOrderModel>,
        orderHistory: results[3] as List<CustomerOrderModel>,
        wallet: results[4] as CustomerWalletModel,
      );
    } on DioException catch (error) {
      throw AppException(
        error.response?.data is Map<String, dynamic>
            ? ((error.response?.data as Map<String, dynamic>)['message']
                      as String? ??
                  'Customer API request failed.')
            : 'Customer API request failed.',
      );
    }
  }

  Future<void> _mutate(
    Future<CustomerDashboardState> Function(CustomerDashboardState current)
    operation,
  ) async {
    final current = state.valueOrNull ?? CustomerDashboardState.initial();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => operation(current));
  }

  Future<void> _startRealtimeSync() async {
    await _orderEventsSubscription?.cancel();
    final stream = await _dataSource.watchOrderEvents();
    _orderEventsSubscription = stream.listen((_) async {
      final current = state.valueOrNull;
      if (current == null) {
        return;
      }

      try {
        final next = await _loadDashboard(current);
        state = AsyncData(next);
      } catch (_) {}
    });
  }
}
