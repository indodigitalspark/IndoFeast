import '../../../../core/config/app_config.dart';
import '../../../../models/delivery_models.dart';
import '../../../../services/api/api_client.dart';
import '../../../../services/realtime/realtime_stream_client.dart';
import '../../../../services/storage/app_storage_service.dart';

class DeliveryRemoteDataSource {
  const DeliveryRemoteDataSource();

  static final _streamClient = createRealtimeStreamClient();

  Future<DeliveryDashboardState> fetchDashboard() async {
    final response = await ApiClient.instance.get<Map<String, dynamic>>(
      '/delivery/dashboard',
    );
    return DeliveryDashboardState.fromMap(response.data ?? <String, dynamic>{});
  }

  Future<void> updateAvailability(bool isOnline) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/delivery/availability',
      data: {'isOnline': isOnline},
    );
  }

  Future<void> acceptOrder(String orderId) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/delivery/orders/$orderId/accept',
    );
  }

  Future<void> confirmPickup(String orderId) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/delivery/orders/$orderId/pickup',
    );
  }

  Future<void> verifyOtp({required String orderId, required String otp}) async {
    await ApiClient.instance.post<Map<String, dynamic>>(
      '/delivery/orders/$orderId/verify-otp',
      data: {'otp': otp},
    );
  }

  Future<void> updateOrderLocation({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    await ApiClient.instance.patch<Map<String, dynamic>>(
      '/delivery/orders/$orderId/location',
      data: {'latitude': latitude, 'longitude': longitude},
    );
  }

  Future<Stream<String>> watchDashboardEvents() async {
    final token = await AppStorageService.getAuthToken();
    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/delivery/dashboard/stream?access_token=${Uri.encodeComponent(token ?? '')}',
    );
    return _streamClient.connect(uri.toString());
  }
}
