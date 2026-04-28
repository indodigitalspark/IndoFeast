import 'package:dio/dio.dart';

import '../../../../core/config/app_config.dart';
import '../../../../models/vendor_models.dart';
import '../../../../services/api/api_client.dart';
import '../../../../services/realtime/realtime_stream_client.dart';
import '../../../../services/storage/app_storage_service.dart';

class VendorRemoteDataSource {
  const VendorRemoteDataSource();

  static final _streamClient = createRealtimeStreamClient();

  Future<VendorDashboardState> fetchDashboard() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/vendor/dashboard',
    );
    final data = response.data ?? <String, dynamic>{};

    return VendorDashboardState(
      restaurant: data['restaurant'] is Map<String, dynamic>
          ? VendorRestaurantModel.fromMap(
              data['restaurant'] as Map<String, dynamic>,
            )
          : null,
      orders: List<Map<String, dynamic>>.from(
        data['orders'] as List? ?? const [],
      ).map(VendorOrderModel.fromMap).toList(growable: false),
      today: VendorReportModel.fromMap(
        data['today'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      weekly: VendorReportModel.fromMap(
        data['weekly'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      monthly: VendorReportModel.fromMap(
        data['monthly'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }

  Future<void> decideOrder({
    required String orderId,
    required String decision,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/vendor/orders/$orderId/decision',
      data: {'decision': decision},
    );
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/vendor/orders/$orderId/status',
      data: {'status': status},
    );
  }

  Future<void> verifyOrderOtp({
    required String orderId,
    required String otp,
  }) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/vendor/orders/$orderId/verify-otp',
      data: {'otp': otp},
    );
  }

  Future<void> updateStoreStatus(String storeStatus) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/vendor/store-status',
      data: {'storeStatus': storeStatus},
    );
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
    final formData = FormData.fromMap({
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'isVeg': '$isVeg',
      'bestseller': '$bestseller',
      'isAvailable': '$isAvailable',
      'discountPercent': discountPercent,
      'preparationTimeMin': preparationTimeMin,
      'preparationTimeMax': preparationTimeMax,
      'addOns': addOns,
      'customizationOptions': customizationOptions,
      if (imageBytes != null && imageName != null)
        'image': MultipartFile.fromBytes(imageBytes, filename: imageName),
    });

    await ApiClient.instance.post<Map<String, dynamic>>(
      '/vendor/products',
      data: formData,
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
    final formData = FormData.fromMap({
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'stock': stock,
      'isVeg': '$isVeg',
      'bestseller': '$bestseller',
      'isAvailable': '$isAvailable',
      'discountPercent': discountPercent,
      'preparationTimeMin': preparationTimeMin,
      'preparationTimeMax': preparationTimeMax,
      'addOns': addOns,
      'customizationOptions': customizationOptions,
      if (imageBytes != null && imageName != null)
        'image': MultipartFile.fromBytes(imageBytes, filename: imageName),
    });

    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/vendor/products/$itemId',
      data: formData,
    );
  }

  Future<void> deleteProduct(String itemId) async {
    await ApiClient.instance.delete<Map<String, dynamic>>(
      '/vendor/products/$itemId',
    );
  }

  Future<void> updateStock({
    required String itemId,
    required int stock,
    required bool isAvailable,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/vendor/products/$itemId/stock',
      data: {'stock': stock, 'isAvailable': isAvailable},
    );
  }

  Future<Stream<String>> watchDashboardEvents() async {
    final token = await AppStorageService.getAuthToken();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/vendor/dashboard/stream?access_token=${Uri.encodeComponent(token ?? '')}',
    );
    return _streamClient.connect(uri.toString());
  }
}
