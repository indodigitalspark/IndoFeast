class VendorProductModel {
  const VendorProductModel({
    required this.itemId,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.isAvailable,
    required this.isVeg,
    required this.bestseller,
    required this.discountPercent,
    required this.preparationTimeMin,
    required this.preparationTimeMax,
    required this.addOns,
    required this.customizationOptions,
    this.imagePath,
  });

  final String itemId;
  final String name;
  final String description;
  final String category;
  final int price;
  final int stock;
  final bool isAvailable;
  final bool isVeg;
  final bool bestseller;
  final int discountPercent;
  final int preparationTimeMin;
  final int preparationTimeMax;
  final List<String> addOns;
  final List<String> customizationOptions;
  final String? imagePath;

  factory VendorProductModel.fromMap(Map<String, dynamic> map) {
    return VendorProductModel(
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'Main Course',
      price: (map['price'] as num? ?? 0).toInt(),
      stock: (map['stock'] as num? ?? 0).toInt(),
      isAvailable: map['isAvailable'] as bool? ?? true,
      isVeg: map['isVeg'] as bool? ?? false,
      bestseller: map['bestseller'] as bool? ?? false,
      discountPercent: (map['discountPercent'] as num? ?? 0).toInt(),
      preparationTimeMin: (map['preparationTimeMin'] as num? ?? 20).toInt(),
      preparationTimeMax: (map['preparationTimeMax'] as num? ?? 25).toInt(),
      addOns: List<String>.from(map['addOns'] as List? ?? const []),
      customizationOptions: List<String>.from(
        map['customizationOptions'] as List? ?? const [],
      ),
      imagePath: map['imagePath'] as String?,
    );
  }
}

class VendorRestaurantModel {
  const VendorRestaurantModel({
    required this.id,
    required this.name,
    required this.offerText,
    required this.description,
    required this.commissionRate,
    required this.pendingSettlementAmount,
    required this.lifetimeSettlementAmount,
    required this.storeStatus,
    required this.products,
  });

  final String id;
  final String name;
  final String offerText;
  final String description;
  final double commissionRate;
  final int pendingSettlementAmount;
  final int lifetimeSettlementAmount;
  final String storeStatus;
  final List<VendorProductModel> products;

  factory VendorRestaurantModel.fromMap(Map<String, dynamic> map) {
    return VendorRestaurantModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      offerText: map['offerText'] as String? ?? '',
      description: map['description'] as String? ?? '',
      commissionRate: (map['commissionRate'] as num? ?? 0).toDouble(),
      pendingSettlementAmount: (map['pendingSettlementAmount'] as num? ?? 0)
          .toInt(),
      lifetimeSettlementAmount: (map['lifetimeSettlementAmount'] as num? ?? 0)
          .toInt(),
      storeStatus: map['storeStatus'] as String? ?? 'OPEN',
      products: List<Map<String, dynamic>>.from(
        map['menuItems'] as List? ?? const [],
      ).map(VendorProductModel.fromMap).toList(growable: false),
    );
  }
}

class VendorOrderItemModel {
  const VendorOrderItemModel({
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  final int price;
  final int quantity;

  factory VendorOrderItemModel.fromMap(Map<String, dynamic> map) {
    return VendorOrderItemModel(
      menuItemId: map['menuItemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toInt(),
      quantity: (map['quantity'] as num? ?? 0).toInt(),
    );
  }
}

class VendorOrderModel {
  const VendorOrderModel({
    required this.id,
    required this.orderMode,
    required this.subtotal,
    required this.total,
    required this.discount,
    required this.status,
    required this.createdAt,
    required this.customerName,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryOtp,
    required this.deliveryPartnerName,
    required this.commissionAmount,
    required this.vendorSettlementAmount,
    required this.items,
  });

  final String id;
  final String orderMode;
  final int subtotal;
  final int total;
  final int discount;
  final String status;
  final DateTime createdAt;
  final String customerName;
  final String paymentMethod;
  final String paymentStatus;
  final String? deliveryOtp;
  final String? deliveryPartnerName;
  final int commissionAmount;
  final int vendorSettlementAmount;
  final List<VendorOrderItemModel> items;

  factory VendorOrderModel.fromMap(Map<String, dynamic> map) {
    return VendorOrderModel(
      id: map['id'] as String? ?? '',
      orderMode: map['orderMode'] as String? ?? 'DELIVERY',
      subtotal: (map['subtotal'] as num? ?? 0).toInt(),
      total: (map['total'] as num? ?? 0).toInt(),
      discount: (map['discount'] as num? ?? 0).toInt(),
      status: map['status'] as String? ?? 'PLACED',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      customerName: map['customerName'] as String? ?? 'Customer',
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      paymentStatus: map['paymentStatus'] as String? ?? 'PENDING',
      deliveryOtp: map['deliveryOtp'] as String?,
      deliveryPartnerName: map['deliveryPartnerName'] as String?,
      commissionAmount: (map['commissionAmount'] as num? ?? 0).toInt(),
      vendorSettlementAmount: (map['vendorSettlementAmount'] as num? ?? 0)
          .toInt(),
      items: List<Map<String, dynamic>>.from(
        map['items'] as List? ?? const [],
      ).map(VendorOrderItemModel.fromMap).toList(growable: false),
    );
  }
}

class VendorReportModel {
  const VendorReportModel({
    required this.grossSales,
    required this.commissionDeduction,
    required this.netPayout,
    required this.orderCount,
    required this.completedOrders,
  });

  final int grossSales;
  final int commissionDeduction;
  final int netPayout;
  final int orderCount;
  final int completedOrders;

  factory VendorReportModel.empty() {
    return const VendorReportModel(
      grossSales: 0,
      commissionDeduction: 0,
      netPayout: 0,
      orderCount: 0,
      completedOrders: 0,
    );
  }

  factory VendorReportModel.fromMap(Map<String, dynamic> map) {
    return VendorReportModel(
      grossSales: (map['grossSales'] as num? ?? 0).toInt(),
      commissionDeduction: (map['commissionDeduction'] as num? ?? 0).toInt(),
      netPayout: (map['netPayout'] as num? ?? 0).toInt(),
      orderCount: (map['orderCount'] as num? ?? 0).toInt(),
      completedOrders: (map['completedOrders'] as num? ?? 0).toInt(),
    );
  }
}

class VendorDashboardState {
  const VendorDashboardState({
    required this.restaurant,
    required this.orders,
    required this.today,
    required this.weekly,
    required this.monthly,
  });

  final VendorRestaurantModel? restaurant;
  final List<VendorOrderModel> orders;
  final VendorReportModel today;
  final VendorReportModel weekly;
  final VendorReportModel monthly;

  factory VendorDashboardState.initial() {
    return VendorDashboardState(
      restaurant: null,
      orders: const [],
      today: VendorReportModel.empty(),
      weekly: VendorReportModel.empty(),
      monthly: VendorReportModel.empty(),
    );
  }

  VendorDashboardState copyWith({
    VendorRestaurantModel? restaurant,
    List<VendorOrderModel>? orders,
    VendorReportModel? today,
    VendorReportModel? weekly,
    VendorReportModel? monthly,
  }) {
    return VendorDashboardState(
      restaurant: restaurant ?? this.restaurant,
      orders: orders ?? this.orders,
      today: today ?? this.today,
      weekly: weekly ?? this.weekly,
      monthly: monthly ?? this.monthly,
    );
  }
}
