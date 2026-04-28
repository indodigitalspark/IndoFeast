import 'app_user.dart';

class DeliveryDashboardState {
  const DeliveryDashboardState({
    required this.partner,
    required this.availableOrders,
    required this.assignedOrders,
    required this.earnings,
    required this.paymentHistory,
  });

  final AppUser partner;
  final List<DeliveryOrderModel> availableOrders;
  final List<DeliveryOrderModel> assignedOrders;
  final DeliveryEarningsModel earnings;
  final List<DeliveryPaymentModel> paymentHistory;

  factory DeliveryDashboardState.fromMap(Map<String, dynamic> map) {
    return DeliveryDashboardState(
      partner: AppUser.fromMap(
        map['partner'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      availableOrders: List<Map<String, dynamic>>.from(
        map['availableOrders'] as List? ?? const [],
      ).map(DeliveryOrderModel.fromMap).toList(growable: false),
      assignedOrders: List<Map<String, dynamic>>.from(
        map['assignedOrders'] as List? ?? const [],
      ).map(DeliveryOrderModel.fromMap).toList(growable: false),
      earnings: DeliveryEarningsModel.fromMap(
        map['earnings'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      paymentHistory: List<Map<String, dynamic>>.from(
        map['paymentHistory'] as List? ?? const [],
      ).map(DeliveryPaymentModel.fromMap).toList(growable: false),
    );
  }
}

class DeliveryOrderModel {
  const DeliveryOrderModel({
    required this.id,
    required this.restaurantName,
    required this.customerName,
    required this.customerPhoneNumber,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.deliveryLatitude,
    required this.deliveryLongitude,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.deliveryOtp,
    required this.deliveryPartnerId,
    required this.deliveryPartnerName,
    required this.deliveryPartnerLatitude,
    required this.deliveryPartnerLongitude,
    required this.locationUpdatedAt,
    required this.deliveryAcceptedAt,
    required this.pickupConfirmedAt,
    required this.itemsSummary,
    required this.tracking,
  });

  final String id;
  final String restaurantName;
  final String customerName;
  final String customerPhoneNumber;
  final String pickupAddress;
  final String deliveryAddress;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final int total;
  final String status;
  final DateTime createdAt;
  final String? deliveryOtp;
  final String? deliveryPartnerId;
  final String? deliveryPartnerName;
  final double? deliveryPartnerLatitude;
  final double? deliveryPartnerLongitude;
  final DateTime? locationUpdatedAt;
  final DateTime? deliveryAcceptedAt;
  final DateTime? pickupConfirmedAt;
  final String itemsSummary;
  final DeliveryTrackingSnapshot tracking;

  bool get isAssigned =>
      deliveryPartnerId != null && deliveryPartnerId!.isNotEmpty;
  bool get canConfirmPickup => isAssigned && pickupConfirmedAt == null;
  bool get canVerifyOtp => pickupConfirmedAt != null && status != 'DELIVERED';

  factory DeliveryOrderModel.fromMap(Map<String, dynamic> map) {
    final items = List<Map<String, dynamic>>.from(
      map['items'] as List? ?? const [],
    );

    return DeliveryOrderModel(
      id: map['id'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      customerName: map['customerName'] as String? ?? 'Customer',
      customerPhoneNumber: map['customerPhoneNumber'] as String? ?? '',
      pickupAddress: map['pickupAddress'] as String? ?? '',
      deliveryAddress: map['deliveryAddress'] as String? ?? '',
      pickupLatitude: (map['pickupLatitude'] as num?)?.toDouble(),
      pickupLongitude: (map['pickupLongitude'] as num?)?.toDouble(),
      deliveryLatitude: (map['deliveryLatitude'] as num?)?.toDouble(),
      deliveryLongitude: (map['deliveryLongitude'] as num?)?.toDouble(),
      total: (map['total'] as num? ?? 0).toInt(),
      status: map['status'] as String? ?? 'ACCEPTED',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      deliveryOtp: map['deliveryOtp'] as String?,
      deliveryPartnerId: map['deliveryPartnerId'] as String?,
      deliveryPartnerName: map['deliveryPartnerName'] as String?,
      deliveryPartnerLatitude: (map['deliveryPartnerLatitude'] as num?)
          ?.toDouble(),
      deliveryPartnerLongitude: (map['deliveryPartnerLongitude'] as num?)
          ?.toDouble(),
      locationUpdatedAt: map['locationUpdatedAt'] is String
          ? DateTime.tryParse(map['locationUpdatedAt'] as String)
          : null,
      deliveryAcceptedAt: map['deliveryAcceptedAt'] is String
          ? DateTime.tryParse(map['deliveryAcceptedAt'] as String)
          : null,
      pickupConfirmedAt: map['pickupConfirmedAt'] is String
          ? DateTime.tryParse(map['pickupConfirmedAt'] as String)
          : null,
      itemsSummary: items
          .map(
            (item) =>
                '${item['quantity'] ?? 0}x ${item['name'] as String? ?? 'Item'}',
          )
          .join(', '),
      tracking: DeliveryTrackingSnapshot.fromMap(
        map['tracking'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class DeliveryTrackingSnapshot {
  const DeliveryTrackingSnapshot({
    required this.distanceKm,
    required this.etaMinutes,
    required this.trafficLabel,
    required this.delayReason,
    required this.canTrackLive,
  });

  final double distanceKm;
  final int etaMinutes;
  final String trafficLabel;
  final String? delayReason;
  final bool canTrackLive;

  factory DeliveryTrackingSnapshot.fromMap(Map<String, dynamic> map) {
    return DeliveryTrackingSnapshot(
      distanceKm: (map['distanceKm'] as num? ?? 0).toDouble(),
      etaMinutes: (map['etaMinutes'] as num? ?? 0).toInt(),
      trafficLabel: map['trafficLabel'] as String? ?? 'Light',
      delayReason: map['delayReason'] as String?,
      canTrackLive: map['canTrackLive'] as bool? ?? false,
    );
  }
}

class DeliveryEarningsModel {
  const DeliveryEarningsModel({
    required this.today,
    required this.weekly,
    required this.monthly,
    required this.lifetime,
    required this.completedTrips,
  });

  final int today;
  final int weekly;
  final int monthly;
  final int lifetime;
  final int completedTrips;

  factory DeliveryEarningsModel.empty() {
    return const DeliveryEarningsModel(
      today: 0,
      weekly: 0,
      monthly: 0,
      lifetime: 0,
      completedTrips: 0,
    );
  }

  factory DeliveryEarningsModel.fromMap(Map<String, dynamic> map) {
    return DeliveryEarningsModel(
      today: (map['today'] as num? ?? 0).toInt(),
      weekly: (map['weekly'] as num? ?? 0).toInt(),
      monthly: (map['monthly'] as num? ?? 0).toInt(),
      lifetime: (map['lifetime'] as num? ?? 0).toInt(),
      completedTrips: (map['completedTrips'] as num? ?? 0).toInt(),
    );
  }
}

class DeliveryPaymentModel {
  const DeliveryPaymentModel({
    required this.amount,
    required this.type,
    required this.description,
    required this.category,
    required this.createdAt,
    this.orderId,
  });

  final int amount;
  final String type;
  final String description;
  final String category;
  final DateTime createdAt;
  final String? orderId;

  factory DeliveryPaymentModel.fromMap(Map<String, dynamic> map) {
    return DeliveryPaymentModel(
      amount: (map['amount'] as num? ?? 0).toInt(),
      type: map['type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'ADJUSTMENT',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      orderId: map['orderId'] as String?,
    );
  }
}
