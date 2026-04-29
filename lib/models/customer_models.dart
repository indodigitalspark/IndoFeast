class OfferBannerModel {
  const OfferBannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  factory OfferBannerModel.fromMap(Map<String, dynamic> map) {
    return OfferBannerModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
    );
  }
}

class CouponModelView {
  const CouponModelView({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
  });

  final String id;
  final String code;
  final String title;
  final String description;
  final String discountType;
  final int discountValue;
  final int minOrderValue;

  factory CouponModelView.fromMap(Map<String, dynamic> map) {
    return CouponModelView(
      id: map['id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      discountType: map['discountType'] as String? ?? '',
      discountValue: (map['discountValue'] as num? ?? 0).toInt(),
      minOrderValue: (map['minOrderValue'] as num? ?? 0).toInt(),
    );
  }
}

class MenuItemModel {
  const MenuItemModel({
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.isVeg,
    required this.bestseller,
    required this.category,
    required this.stock,
    required this.isAvailable,
    required this.imagePath,
    required this.discountPercent,
    required this.preparationTimeMin,
    required this.preparationTimeMax,
    required this.addOns,
    required this.customizationOptions,
  });

  final String itemId;
  final String name;
  final String description;
  final int price;
  final bool isVeg;
  final bool bestseller;
  final String category;
  final int stock;
  final bool isAvailable;
  final String? imagePath;
  final int discountPercent;
  final int preparationTimeMin;
  final int preparationTimeMax;
  final List<String> addOns;
  final List<String> customizationOptions;

  factory MenuItemModel.fromMap(Map<String, dynamic> map) {
    return MenuItemModel(
      itemId: map['itemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toInt(),
      isVeg: map['isVeg'] as bool? ?? false,
      bestseller: map['bestseller'] as bool? ?? false,
      category: map['category'] as String? ?? 'Food',
      stock: (map['stock'] as num? ?? 0).toInt(),
      isAvailable: map['isAvailable'] as bool? ?? true,
      imagePath: map['imagePath'] as String?,
      discountPercent: (map['discountPercent'] as num? ?? 0).toInt(),
      preparationTimeMin: (map['preparationTimeMin'] as num? ?? 20).toInt(),
      preparationTimeMax: (map['preparationTimeMax'] as num? ?? 25).toInt(),
      addOns: List<String>.from(map['addOns'] as List? ?? const []),
      customizationOptions: List<String>.from(
        map['customizationOptions'] as List? ?? const [],
      ),
    );
  }
}

class ReviewModel {
  const ReviewModel({
    required this.userName,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  final String userName;
  final double rating;
  final String review;
  final DateTime createdAt;

  factory ReviewModel.fromMap(Map<String, dynamic> map) {
    return ReviewModel(
      userName: map['userName'] as String? ?? 'Guest',
      rating: (map['rating'] as num? ?? 0).toDouble(),
      review: map['review'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class RestaurantModelView {
  const RestaurantModelView({
    required this.id,
    required this.name,
    required this.cuisine,
    required this.category,
    required this.rating,
    required this.deliveryTime,
    required this.priceLevel,
    required this.offerText,
    required this.description,
    required this.accentColor,
    required this.heroTag,
    required this.storeStatus,
    required this.menuItems,
    required this.reviews,
  });

  final String id;
  final String name;
  final List<String> cuisine;
  final String category;
  final double rating;
  final int deliveryTime;
  final String priceLevel;
  final String offerText;
  final String description;
  final String accentColor;
  final String heroTag;
  final String storeStatus;
  final List<MenuItemModel> menuItems;
  final List<ReviewModel> reviews;

  bool get isOpen => storeStatus == 'OPEN';

  factory RestaurantModelView.fromMap(Map<String, dynamic> map) {
    return RestaurantModelView(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      cuisine: List<String>.from(map['cuisine'] as List? ?? const []),
      category: map['category'] as String? ?? '',
      rating: (map['rating'] as num? ?? 0).toDouble(),
      deliveryTime: (map['deliveryTime'] as num? ?? 0).toInt(),
      priceLevel: map['priceLevel'] as String? ?? '',
      offerText: map['offerText'] as String? ?? '',
      description: map['description'] as String? ?? '',
      accentColor: map['accentColor'] as String? ?? '#FFF4EA',
      heroTag: map['heroTag'] as String? ?? '',
      storeStatus: map['storeStatus'] as String? ?? 'OPEN',
      menuItems: List<Map<String, dynamic>>.from(
        map['menuItems'] as List? ?? const [],
      ).map(MenuItemModel.fromMap).toList(growable: false),
      reviews: List<Map<String, dynamic>>.from(
        map['reviews'] as List? ?? const [],
      ).map(ReviewModel.fromMap).toList(growable: false),
    );
  }
}

class CartItemModel {
  const CartItemModel({
    required this.restaurantId,
    required this.restaurantName,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  final String restaurantId;
  final String restaurantName;
  final String menuItemId;
  final String name;
  final int price;
  final int quantity;

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      restaurantId: map['restaurantId'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      menuItemId: map['menuItemId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num? ?? 0).toInt(),
      quantity: (map['quantity'] as num? ?? 0).toInt(),
    );
  }
}

class CustomerCartModel {
  const CustomerCartModel({
    required this.items,
    required this.storeGroups,
    required this.couponCode,
    required this.discount,
    required this.orderMode,
    required this.paymentMethod,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.grandTotal,
    required this.grandItemCount,
    required this.splitOrderMessage,
  });

  final List<CartItemModel> items;
  final List<CartStoreGroupModel> storeGroups;
  final String? couponCode;
  final int discount;
  final String orderMode;
  final String paymentMethod;
  final int subtotal;
  final int deliveryFee;
  final int tax;
  final int total;
  final int grandTotal;
  final int grandItemCount;
  final String splitOrderMessage;

  factory CustomerCartModel.empty() {
    return const CustomerCartModel(
      items: [],
      storeGroups: [],
      couponCode: null,
      discount: 0,
      orderMode: 'DELIVERY',
      paymentMethod: 'COD',
      subtotal: 0,
      deliveryFee: 0,
      tax: 0,
      total: 0,
      grandTotal: 0,
      grandItemCount: 0,
      splitOrderMessage: '',
    );
  }

  factory CustomerCartModel.fromMap(Map<String, dynamic> map) {
    return CustomerCartModel(
      items: List<Map<String, dynamic>>.from(
        map['items'] as List? ?? const [],
      ).map(CartItemModel.fromMap).toList(growable: false),
      storeGroups: List<Map<String, dynamic>>.from(
        map['storeGroups'] as List? ?? const [],
      ).map(CartStoreGroupModel.fromMap).toList(growable: false),
      couponCode: map['couponCode'] as String?,
      discount: (map['discount'] as num? ?? 0).toInt(),
      orderMode: map['orderMode'] as String? ?? 'DELIVERY',
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      subtotal: (map['subtotal'] as num? ?? 0).toInt(),
      deliveryFee: (map['deliveryFee'] as num? ?? 0).toInt(),
      tax: (map['tax'] as num? ?? 0).toInt(),
      total: (map['total'] as num? ?? 0).toInt(),
      grandTotal: (map['grandTotal'] as num? ?? map['total'] as num? ?? 0)
          .toInt(),
      grandItemCount: (map['grandItemCount'] as num? ?? 0).toInt(),
      splitOrderMessage: map['splitOrderMessage'] as String? ?? '',
    );
  }
}

class CartStoreGroupModel {
  const CartStoreGroupModel({
    required this.storeId,
    required this.storeName,
    required this.itemCount,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.items,
  });

  final String storeId;
  final String storeName;
  final int itemCount;
  final int subtotal;
  final int deliveryFee;
  final int tax;
  final int total;
  final List<CartItemModel> items;

  factory CartStoreGroupModel.fromMap(Map<String, dynamic> map) {
    return CartStoreGroupModel(
      storeId: map['storeId'] as String? ?? '',
      storeName: map['storeName'] as String? ?? '',
      itemCount: (map['itemCount'] as num? ?? 0).toInt(),
      subtotal: (map['subtotal'] as num? ?? 0).toInt(),
      deliveryFee: (map['deliveryFee'] as num? ?? 0).toInt(),
      tax: (map['tax'] as num? ?? 0).toInt(),
      total: (map['total'] as num? ?? 0).toInt(),
      items: List<Map<String, dynamic>>.from(
        map['items'] as List? ?? const [],
      ).map(CartItemModel.fromMap).toList(growable: false),
    );
  }
}

class OrderReviewModel {
  const OrderReviewModel({
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final int rating;
  final String comment;
  final DateTime createdAt;

  factory OrderReviewModel.fromMap(Map<String, dynamic> map) {
    return OrderReviewModel(
      rating: (map['rating'] as num? ?? 0).toInt(),
      comment: map['comment'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CustomerOrderModel {
  const CustomerOrderModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.items,
    required this.orderMode,
    required this.couponCode,
    required this.discount,
    required this.subtotal,
    required this.deliveryFee,
    required this.tax,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.deliveryOtp,
    required this.paymentReferenceId,
    required this.paymentProviderOrderId,
    required this.paymentClientSecret,
    required this.paymentSessionId,
    required this.checkoutSessionId,
    required this.orderGroupId,
    required this.splitSequence,
    required this.refundedAmount,
    required this.deliveryAddress,
    required this.deliveryPartnerName,
    required this.tracking,
    required this.createdAt,
    required this.updatedAt,
    required this.review,
  });

  final String id;
  final String restaurantId;
  final String restaurantName;
  final List<CartItemModel> items;
  final String orderMode;
  final String? couponCode;
  final int discount;
  final int subtotal;
  final int deliveryFee;
  final int tax;
  final int total;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? deliveryOtp;
  final String? paymentReferenceId;
  final String? paymentProviderOrderId;
  final String? paymentClientSecret;
  final String? paymentSessionId;
  final String? checkoutSessionId;
  final String? orderGroupId;
  final int splitSequence;
  final int refundedAmount;
  final String deliveryAddress;
  final String? deliveryPartnerName;
  final DeliveryTrackingModel tracking;
  final DateTime createdAt;
  final DateTime updatedAt;
  final OrderReviewModel? review;

  bool get canReview => status == 'DELIVERED' && review == null;

  factory CustomerOrderModel.fromMap(Map<String, dynamic> map) {
    return CustomerOrderModel(
      id: map['id'] as String? ?? '',
      restaurantId: map['restaurantId'] as String? ?? '',
      restaurantName: map['restaurantName'] as String? ?? '',
      items: List<Map<String, dynamic>>.from(
        map['items'] as List? ?? const [],
      ).map(CartItemModel.fromMap).toList(growable: false),
      orderMode: map['orderMode'] as String? ?? 'DELIVERY',
      couponCode: map['couponCode'] as String?,
      discount: (map['discount'] as num? ?? 0).toInt(),
      subtotal: (map['subtotal'] as num? ?? 0).toInt(),
      deliveryFee: (map['deliveryFee'] as num? ?? 0).toInt(),
      tax: (map['tax'] as num? ?? 0).toInt(),
      total: (map['total'] as num? ?? 0).toInt(),
      status: map['status'] as String? ?? 'PLACED',
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      paymentStatus: map['paymentStatus'] as String? ?? 'PENDING',
      deliveryOtp: map['deliveryOtp'] as String?,
      paymentReferenceId: map['paymentReferenceId'] as String?,
      paymentProviderOrderId: map['paymentProviderOrderId'] as String?,
      paymentClientSecret: map['paymentClientSecret'] as String?,
      paymentSessionId: map['paymentSessionId'] as String?,
      checkoutSessionId: map['checkoutSessionId'] as String?,
      orderGroupId: map['orderGroupId'] as String?,
      splitSequence: (map['splitSequence'] as num? ?? 1).toInt(),
      refundedAmount: (map['refundedAmount'] as num? ?? 0).toInt(),
      deliveryAddress: map['deliveryAddress'] as String? ?? '',
      deliveryPartnerName: map['deliveryPartnerName'] as String?,
      tracking: DeliveryTrackingModel.fromMap(
        map['tracking'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      review: map['review'] is Map<String, dynamic>
          ? OrderReviewModel.fromMap(map['review'] as Map<String, dynamic>)
          : null,
    );
  }
}

class DeliveryTrackingModel {
  const DeliveryTrackingModel({
    required this.distanceKm,
    required this.etaMinutes,
    required this.trafficLabel,
    required this.delayReason,
    required this.canTrackLive,
    required this.routeStage,
  });

  final double distanceKm;
  final int etaMinutes;
  final String trafficLabel;
  final String? delayReason;
  final bool canTrackLive;
  final String routeStage;

  factory DeliveryTrackingModel.fromMap(Map<String, dynamic> map) {
    return DeliveryTrackingModel(
      distanceKm: (map['distanceKm'] as num? ?? 0).toDouble(),
      etaMinutes: (map['etaMinutes'] as num? ?? 0).toInt(),
      trafficLabel: map['trafficLabel'] as String? ?? 'Light',
      delayReason: map['delayReason'] as String?,
      canTrackLive: map['canTrackLive'] as bool? ?? false,
      routeStage: map['routeStage'] as String? ?? 'STORE_TO_CUSTOMER',
    );
  }
}

class WalletTransactionModel {
  const WalletTransactionModel({
    required this.amount,
    required this.type,
    required this.description,
    required this.category,
    required this.createdAt,
  });

  final int amount;
  final String type;
  final String description;
  final String category;
  final DateTime createdAt;

  factory WalletTransactionModel.fromMap(Map<String, dynamic> map) {
    return WalletTransactionModel(
      amount: (map['amount'] as num? ?? 0).toInt(),
      type: map['type'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? 'ADJUSTMENT',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CustomerWalletModel {
  const CustomerWalletModel({
    required this.walletBalance,
    required this.transactions,
  });

  final int walletBalance;
  final List<WalletTransactionModel> transactions;

  factory CustomerWalletModel.empty() {
    return const CustomerWalletModel(walletBalance: 0, transactions: []);
  }

  factory CustomerWalletModel.fromMap(Map<String, dynamic> map) {
    return CustomerWalletModel(
      walletBalance: (map['walletBalance'] as num? ?? 0).toInt(),
      transactions: List<Map<String, dynamic>>.from(
        map['transactions'] as List? ?? const [],
      ).map(WalletTransactionModel.fromMap).toList(growable: false),
    );
  }
}

class CustomerDashboardState {
  const CustomerDashboardState({
    required this.banners,
    required this.categories,
    required this.coupons,
    required this.restaurants,
    required this.cart,
    required this.activeOrders,
    required this.orderHistory,
    required this.wallet,
    required this.search,
    required this.selectedCategory,
    required this.minRating,
    required this.maxDeliveryTime,
    required this.priceFilter,
  });

  final List<OfferBannerModel> banners;
  final List<String> categories;
  final List<CouponModelView> coupons;
  final List<RestaurantModelView> restaurants;
  final CustomerCartModel cart;
  final List<CustomerOrderModel> activeOrders;
  final List<CustomerOrderModel> orderHistory;
  final CustomerWalletModel wallet;
  final String search;
  final String selectedCategory;
  final double? minRating;
  final int? maxDeliveryTime;
  final String? priceFilter;

  factory CustomerDashboardState.initial() {
    return CustomerDashboardState(
      banners: const [],
      categories: const ['All'],
      coupons: const [],
      restaurants: const [],
      cart: CustomerCartModel.empty(),
      activeOrders: const [],
      orderHistory: const [],
      wallet: CustomerWalletModel.empty(),
      search: '',
      selectedCategory: 'All',
      minRating: null,
      maxDeliveryTime: null,
      priceFilter: null,
    );
  }

  CustomerDashboardState copyWith({
    List<OfferBannerModel>? banners,
    List<String>? categories,
    List<CouponModelView>? coupons,
    List<RestaurantModelView>? restaurants,
    CustomerCartModel? cart,
    List<CustomerOrderModel>? activeOrders,
    List<CustomerOrderModel>? orderHistory,
    CustomerWalletModel? wallet,
    String? search,
    String? selectedCategory,
    double? minRating,
    int? maxDeliveryTime,
    String? priceFilter,
    bool clearRating = false,
    bool clearDeliveryTime = false,
    bool clearPrice = false,
  }) {
    return CustomerDashboardState(
      banners: banners ?? this.banners,
      categories: categories ?? this.categories,
      coupons: coupons ?? this.coupons,
      restaurants: restaurants ?? this.restaurants,
      cart: cart ?? this.cart,
      activeOrders: activeOrders ?? this.activeOrders,
      orderHistory: orderHistory ?? this.orderHistory,
      wallet: wallet ?? this.wallet,
      search: search ?? this.search,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      minRating: clearRating ? null : minRating ?? this.minRating,
      maxDeliveryTime: clearDeliveryTime
          ? null
          : maxDeliveryTime ?? this.maxDeliveryTime,
      priceFilter: clearPrice ? null : priceFilter ?? this.priceFilter,
    );
  }
}

class CustomerCheckoutModel {
  const CustomerCheckoutModel({
    required this.checkoutSession,
    required this.orders,
    required this.checkout,
  });

  final CustomerCheckoutSessionModel? checkoutSession;
  final List<CustomerOrderModel> orders;
  final Map<String, dynamic>? checkout;

  factory CustomerCheckoutModel.fromMap(Map<String, dynamic> map) {
    return CustomerCheckoutModel(
      checkoutSession: map['checkoutSession'] is Map<String, dynamic>
          ? CustomerCheckoutSessionModel.fromMap(
              map['checkoutSession'] as Map<String, dynamic>,
            )
          : null,
      orders: List<Map<String, dynamic>>.from(
        map['orders'] as List? ?? const [],
      ).map(CustomerOrderModel.fromMap).toList(growable: false),
      checkout: map['checkout'] as Map<String, dynamic>?,
    );
  }
}

class CustomerCheckoutSessionModel {
  const CustomerCheckoutSessionModel({
    required this.id,
    required this.orderGroupId,
    required this.orderMode,
    required this.paymentMethod,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.discount,
    required this.deliveryFee,
    required this.tax,
    required this.grandTotal,
    required this.stores,
  });

  final String id;
  final String orderGroupId;
  final String orderMode;
  final String paymentMethod;
  final String status;
  final String paymentStatus;
  final int subtotal;
  final int discount;
  final int deliveryFee;
  final int tax;
  final int grandTotal;
  final List<CartStoreGroupModel> stores;

  factory CustomerCheckoutSessionModel.fromMap(Map<String, dynamic> map) {
    return CustomerCheckoutSessionModel(
      id: map['id'] as String? ?? '',
      orderGroupId: map['orderGroupId'] as String? ?? '',
      orderMode: map['orderMode'] as String? ?? 'DELIVERY',
      paymentMethod: map['paymentMethod'] as String? ?? 'COD',
      status: map['status'] as String? ?? 'PENDING_PAYMENT',
      paymentStatus: map['paymentStatus'] as String? ?? 'PENDING',
      subtotal: (map['subtotal'] as num? ?? 0).toInt(),
      discount: (map['discount'] as num? ?? 0).toInt(),
      deliveryFee: (map['deliveryFee'] as num? ?? 0).toInt(),
      tax: (map['tax'] as num? ?? 0).toInt(),
      grandTotal: (map['grandTotal'] as num? ?? 0).toInt(),
      stores: List<Map<String, dynamic>>.from(
        map['stores'] as List? ?? const [],
      ).map(CartStoreGroupModel.fromMap).toList(growable: false),
    );
  }
}
