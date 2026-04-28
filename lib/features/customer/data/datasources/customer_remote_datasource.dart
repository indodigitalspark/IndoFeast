import '../../../../core/config/app_config.dart';
import '../../../../models/customer_models.dart';
import '../../../../services/api/api_client.dart';
import '../../../../services/realtime/realtime_stream_client.dart';
import '../../../../services/storage/app_storage_service.dart';

class CustomerRemoteDataSource {
  const CustomerRemoteDataSource();

  static final _streamClient = createRealtimeStreamClient();

  Future<Map<String, dynamic>> fetchHome({
    required String search,
    required String category,
    double? minRating,
    int? maxDeliveryTime,
    String? priceFilter,
  }) async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customer/home',
      queryParameters: <String, dynamic>{
        'search': search,
        if (category != 'All') 'category': category,
        'rating': minRating,
        'deliveryTime': maxDeliveryTime,
        if (priceFilter != null && priceFilter.isNotEmpty) 'price': priceFilter,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<CustomerCartModel> fetchCart() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customer/cart',
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCartModel> addToCart({
    required String restaurantId,
    required String menuItemId,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/cart/items',
      data: {'restaurantId': restaurantId, 'menuItemId': menuItemId},
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCartModel> updateCartItem({
    required String restaurantId,
    required String menuItemId,
    required String action,
  }) async {
    final response = await ApiClient.instance.patch<Map<String, dynamic>>(
      '/customer/cart/items',
      data: {
        'restaurantId': restaurantId,
        'menuItemId': menuItemId,
        'action': action,
      },
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCartModel> applyCoupon(String? code) async {
    final response = await ApiClient.instance.patch<Map<String, dynamic>>(
      '/customer/cart/coupon',
      data: {'code': code},
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCartModel> updateOrderMode(String orderMode) async {
    final response = await ApiClient.instance.patch<Map<String, dynamic>>(
      '/customer/cart/mode',
      data: {'orderMode': orderMode},
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCartModel> updatePaymentMethod(String paymentMethod) async {
    final response = await ApiClient.instance.patch<Map<String, dynamic>>(
      '/customer/cart/payment',
      data: {'paymentMethod': paymentMethod},
    );
    return CustomerCartModel.fromMap(
      response.data?['cart'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<CustomerCheckoutModel> placeOrder(String paymentMethod) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/orders',
      data: {'paymentMethod': paymentMethod},
    );
    return CustomerCheckoutModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> cancelOrder(String orderId) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/orders/$orderId/cancel',
    );
  }

  Future<CustomerOrderModel> verifyPayment({
    required String orderId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/orders/$orderId/payment/verify',
      data: payload,
    );
    return CustomerOrderModel.fromMap(
      response.data?['order'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );
  }

  Future<List<CustomerOrderModel>> fetchActiveOrders() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customer/orders/active',
    );
    return List<Map<String, dynamic>>.from(
      response.data?['orders'] as List? ?? const [],
    ).map(CustomerOrderModel.fromMap).toList(growable: false);
  }

  Future<List<CustomerOrderModel>> fetchOrderHistory() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customer/orders/history',
    );
    return List<Map<String, dynamic>>.from(
      response.data?['orders'] as List? ?? const [],
    ).map(CustomerOrderModel.fromMap).toList(growable: false);
  }

  Future<CustomerWalletModel> fetchWallet() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/customer/wallet',
    );
    return CustomerWalletModel.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<CustomerWalletModel> addWalletFunds(int amount) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/wallet/add-funds',
      data: {'amount': amount},
    );
    return fetchWallet();
  }

  Future<void> submitReview({
    required String orderId,
    required int rating,
    required String comment,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/customer/orders/$orderId/review',
      data: {'rating': rating, 'comment': comment},
    );
  }

  Future<Stream<String>> watchOrderEvents() async {
    final token = await AppStorageService.getAuthToken();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/customer/orders/stream?access_token=${Uri.encodeComponent(token ?? '')}',
    );
    return _streamClient.connect(uri.toString());
  }
}
