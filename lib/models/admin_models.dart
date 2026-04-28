import 'app_user.dart';
import 'admin_notification.dart';

class AdminDashboardState {
  const AdminDashboardState({
    required this.analytics,
    required this.users,
    required this.restaurants,
    required this.transactions,
    required this.notifications,
    required this.config,
    required this.report,
  });

  final AdminAnalytics analytics;
  final List<AppUser> users;
  final List<AdminRestaurantModel> restaurants;
  final List<AdminTransactionModel> transactions;
  final List<AdminNotification> notifications;
  final AdminPlatformConfig config;
  final AdminReportModel report;

  List<AppUser> get pendingUsers => users
      .where((user) => user.status.value == 'PENDING')
      .toList(growable: false);

  List<AppUser> get vendorApprovals => users
      .where(
        (user) => user.role.value == 'VENDOR' && user.status.value == 'PENDING',
      )
      .toList(growable: false);

  List<AppUser> get deliveryApprovals => users
      .where(
        (user) =>
            user.role.value == 'DELIVERY_PARTNER' &&
            user.status.value == 'PENDING',
      )
      .toList(growable: false);

  factory AdminDashboardState.fromMap(Map<String, dynamic> map) {
    return AdminDashboardState(
      analytics: AdminAnalytics.fromMap(
        map['analytics'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      users: List<Map<String, dynamic>>.from(
        map['users'] as List? ?? const [],
      ).map(AppUser.fromMap).toList(growable: false),
      restaurants: List<Map<String, dynamic>>.from(
        map['restaurants'] as List? ?? const [],
      ).map(AdminRestaurantModel.fromMap).toList(growable: false),
      transactions: List<Map<String, dynamic>>.from(
        map['transactions'] as List? ?? const [],
      ).map(AdminTransactionModel.fromMap).toList(growable: false),
      notifications:
          List<Map<String, dynamic>>.from(
                map['notifications'] as List? ?? const [],
              )
              .map(
                (item) => AdminNotification.fromMap(
                  item['id'] as String? ?? '',
                  item,
                ),
              )
              .toList(growable: false),
      config: AdminPlatformConfig.fromMap(
        map['config'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      report: AdminReportModel.fromMap(
        map['report'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class AdminAnalytics {
  const AdminAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.activeVendors,
    required this.activeDeliveryPartners,
    required this.totalUsers,
    required this.pendingApprovals,
    required this.suspendedAccounts,
    required this.totalRestaurants,
    required this.completionRate,
  });

  final int totalRevenue;
  final int totalOrders;
  final int activeVendors;
  final int activeDeliveryPartners;
  final int totalUsers;
  final int pendingApprovals;
  final int suspendedAccounts;
  final int totalRestaurants;
  final int completionRate;

  factory AdminAnalytics.fromMap(Map<String, dynamic> map) {
    return AdminAnalytics(
      totalRevenue: (map['totalRevenue'] as num? ?? 0).toInt(),
      totalOrders: (map['totalOrders'] as num? ?? 0).toInt(),
      activeVendors: (map['activeVendors'] as num? ?? 0).toInt(),
      activeDeliveryPartners: (map['activeDeliveryPartners'] as num? ?? 0)
          .toInt(),
      totalUsers: (map['totalUsers'] as num? ?? 0).toInt(),
      pendingApprovals: (map['pendingApprovals'] as num? ?? 0).toInt(),
      suspendedAccounts: (map['suspendedAccounts'] as num? ?? 0).toInt(),
      totalRestaurants: (map['totalRestaurants'] as num? ?? 0).toInt(),
      completionRate: (map['completionRate'] as num? ?? 0).toInt(),
    );
  }
}

class AdminPlatformConfig {
  const AdminPlatformConfig({
    required this.globalCommissionRate,
    required this.roleDefinitions,
    required this.managedCategories,
    required this.marketingBanners,
    required this.websiteSettings,
  });

  final double globalCommissionRate;
  final List<AdminRoleDefinition> roleDefinitions;
  final List<AdminCategoryModel> managedCategories;
  final List<AdminBannerModel> marketingBanners;
  final AdminWebsiteSettings websiteSettings;

  factory AdminPlatformConfig.fromMap(Map<String, dynamic> map) {
    return AdminPlatformConfig(
      globalCommissionRate: (map['globalCommissionRate'] as num? ?? 0.18)
          .toDouble(),
      roleDefinitions: List<Map<String, dynamic>>.from(
        map['roleDefinitions'] as List? ?? const [],
      ).map(AdminRoleDefinition.fromMap).toList(growable: false),
      managedCategories: List<Map<String, dynamic>>.from(
        map['managedCategories'] as List? ?? const [],
      ).map(AdminCategoryModel.fromMap).toList(growable: false),
      marketingBanners: List<Map<String, dynamic>>.from(
        map['marketingBanners'] as List? ?? const [],
      ).map(AdminBannerModel.fromMap).toList(growable: false),
      websiteSettings: AdminWebsiteSettings.fromMap(
        map['websiteSettings'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
    );
  }
}

class AdminWebsiteSettings {
  const AdminWebsiteSettings({
    required this.headline,
    required this.subtitle,
    required this.qrLinks,
  });

  final String headline;
  final String subtitle;
  final List<AdminWebsiteQrLink> qrLinks;

  factory AdminWebsiteSettings.fromMap(Map<String, dynamic> map) {
    return AdminWebsiteSettings(
      headline: map['headline'] as String? ?? 'IndoFeast Digital Entry',
      subtitle: map['subtitle'] as String? ?? '',
      qrLinks: List<Map<String, dynamic>>.from(
        map['qrLinks'] as List? ?? const [],
      ).map(AdminWebsiteQrLink.fromMap).toList(growable: false),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'headline': headline,
      'subtitle': subtitle,
      'qrLinks': qrLinks.map((item) => item.toMap()).toList(growable: false),
    };
  }
}

class AdminWebsiteQrLink {
  const AdminWebsiteQrLink({
    required this.id,
    required this.title,
    required this.description,
    required this.url,
    required this.isActive,
  });

  final String id;
  final String title;
  final String description;
  final String url;
  final bool isActive;

  factory AdminWebsiteQrLink.fromMap(Map<String, dynamic> map) {
    return AdminWebsiteQrLink(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      url: map['url'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'url': url,
      'isActive': isActive,
    };
  }
}

class AdminRoleDefinition {
  const AdminRoleDefinition({
    required this.key,
    required this.name,
    required this.permissions,
    required this.isSystem,
  });

  final String key;
  final String name;
  final List<String> permissions;
  final bool isSystem;

  factory AdminRoleDefinition.fromMap(Map<String, dynamic> map) {
    return AdminRoleDefinition(
      key: map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      permissions: List<String>.from(map['permissions'] as List? ?? const []),
      isSystem: map['isSystem'] as bool? ?? false,
    );
  }
}

class AdminCategoryModel {
  const AdminCategoryModel({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final String id;
  final String name;
  final bool isActive;

  factory AdminCategoryModel.fromMap(Map<String, dynamic> map) {
    return AdminCategoryModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class AdminBannerModel {
  const AdminBannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.isActive,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaText;
  final bool isActive;

  factory AdminBannerModel.fromMap(Map<String, dynamic> map) {
    return AdminBannerModel(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      ctaText: map['ctaText'] as String? ?? 'Order now',
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class AdminTransactionModel {
  const AdminTransactionModel({
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.amount,
    required this.type,
    required this.category,
    required this.description,
    required this.createdAt,
    this.orderId,
  });

  final String userId;
  final String userName;
  final String userRole;
  final int amount;
  final String type;
  final String category;
  final String description;
  final DateTime createdAt;
  final String? orderId;

  factory AdminTransactionModel.fromMap(Map<String, dynamic> map) {
    return AdminTransactionModel(
      userId: map['userId'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userRole: map['userRole'] as String? ?? '',
      amount: (map['amount'] as num? ?? 0).toInt(),
      type: map['type'] as String? ?? '',
      category: map['category'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      orderId: map['orderId'] as String?,
    );
  }
}

class AdminReportModel {
  const AdminReportModel({
    required this.days,
    required this.generatedAt,
    required this.summary,
    required this.ordersByStatus,
    required this.topVendors,
    required this.totalCredits,
    required this.totalDebits,
    required this.totalPlatformProfit,
    required this.totalVendorEarnings,
  });

  final int days;
  final DateTime generatedAt;
  final AdminAnalytics summary;
  final Map<String, int> ordersByStatus;
  final List<AdminTopVendorModel> topVendors;
  final int totalCredits;
  final int totalDebits;
  final int totalPlatformProfit;
  final int totalVendorEarnings;

  factory AdminReportModel.fromMap(Map<String, dynamic> map) {
    return AdminReportModel(
      days: (map['days'] as num? ?? 30).toInt(),
      generatedAt:
          DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
          DateTime.now(),
      summary: AdminAnalytics.fromMap(
        map['summary'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      ordersByStatus: Map<String, int>.fromEntries(
        (map['ordersByStatus'] as Map<String, dynamic>? ?? <String, dynamic>{})
            .entries
            .map((entry) => MapEntry(entry.key, (entry.value as num).toInt())),
      ),
      topVendors: List<Map<String, dynamic>>.from(
        map['topVendors'] as List? ?? const [],
      ).map(AdminTopVendorModel.fromMap).toList(growable: false),
      totalCredits: (map['totalCredits'] as num? ?? 0).toInt(),
      totalDebits: (map['totalDebits'] as num? ?? 0).toInt(),
      totalPlatformProfit: (map['totalPlatformProfit'] as num? ?? 0).toInt(),
      totalVendorEarnings: (map['totalVendorEarnings'] as num? ?? 0).toInt(),
    );
  }
}

class AdminTopVendorModel {
  const AdminTopVendorModel({
    required this.restaurantName,
    required this.orders,
    required this.revenue,
    required this.platformProfit,
    required this.vendorEarnings,
  });

  final String restaurantName;
  final int orders;
  final int revenue;
  final int platformProfit;
  final int vendorEarnings;

  factory AdminTopVendorModel.fromMap(Map<String, dynamic> map) {
    return AdminTopVendorModel(
      restaurantName: map['restaurantName'] as String? ?? '',
      orders: (map['orders'] as num? ?? 0).toInt(),
      revenue: (map['revenue'] as num? ?? 0).toInt(),
      platformProfit: (map['platformProfit'] as num? ?? 0).toInt(),
      vendorEarnings: (map['vendorEarnings'] as num? ?? 0).toInt(),
    );
  }
}

class AdminRestaurantModel {
  const AdminRestaurantModel({
    required this.id,
    required this.name,
    required this.category,
    required this.cuisine,
    required this.description,
    required this.offerText,
    required this.deliveryTime,
    required this.priceLevel,
    required this.commissionRate,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.productCount,
  });

  final String id;
  final String name;
  final String category;
  final List<String> cuisine;
  final String description;
  final String offerText;
  final int deliveryTime;
  final String priceLevel;
  final double commissionRate;
  final String? ownerId;
  final String? ownerName;
  final String? ownerEmail;
  final int productCount;

  factory AdminRestaurantModel.fromMap(Map<String, dynamic> map) {
    return AdminRestaurantModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Meals',
      cuisine: List<String>.from(map['cuisine'] as List? ?? const []),
      description: map['description'] as String? ?? '',
      offerText: map['offerText'] as String? ?? '',
      deliveryTime: (map['deliveryTime'] as num? ?? 0).toInt(),
      priceLevel: map['priceLevel'] as String? ?? '',
      commissionRate: (map['commissionRate'] as num? ?? 0.18).toDouble(),
      ownerId: map['ownerId'] as String?,
      ownerName: map['ownerName'] as String?,
      ownerEmail: map['ownerEmail'] as String?,
      productCount: List<Map<String, dynamic>>.from(
        map['menuItems'] as List? ?? const [],
      ).length,
    );
  }
}
