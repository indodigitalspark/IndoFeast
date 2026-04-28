import 'account_status.dart';
import 'user_role.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    required this.role,
    required this.status,
    required this.createdAt,
    this.customRoleKey,
    this.customRoleName,
    this.permissions = const [],
    this.walletBalance = 0,
    this.walletTransactions = const [],
    this.deliveryProfile,
    this.documentUrl,
    this.documentName,
    this.rejectionReason,
  });

  final String id;
  final String email;
  final String displayName;
  final String phoneNumber;
  final UserRole role;
  final AccountStatus status;
  final DateTime createdAt;
  final String? customRoleKey;
  final String? customRoleName;
  final List<String> permissions;
  final int walletBalance;
  final List<UserWalletTransaction> walletTransactions;
  final DeliveryProfileSnapshot? deliveryProfile;
  final String? documentUrl;
  final String? documentName;
  final String? rejectionReason;

  bool get canAccessDashboard => status == AccountStatus.approved;
  bool get isAdminFamily => role.isAdminFamily;
  bool get hasFullAdminAccess =>
      role == UserRole.superAdmin || role == UserRole.admin;

  bool hasPermission(String permission) {
    if (hasFullAdminAccess) {
      return true;
    }

    return permissions.contains(permission);
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    UserRole? role,
    AccountStatus? status,
    DateTime? createdAt,
    String? customRoleKey,
    String? customRoleName,
    List<String>? permissions,
    int? walletBalance,
    List<UserWalletTransaction>? walletTransactions,
    DeliveryProfileSnapshot? deliveryProfile,
    String? documentUrl,
    String? documentName,
    String? rejectionReason,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      customRoleKey: customRoleKey ?? this.customRoleKey,
      customRoleName: customRoleName ?? this.customRoleName,
      permissions: permissions ?? this.permissions,
      walletBalance: walletBalance ?? this.walletBalance,
      walletTransactions: walletTransactions ?? this.walletTransactions,
      deliveryProfile: deliveryProfile ?? this.deliveryProfile,
      documentUrl: documentUrl ?? this.documentUrl,
      documentName: documentName ?? this.documentName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.value,
      'status': status.value,
      'createdAt': createdAt.toIso8601String(),
      'customRoleKey': customRoleKey,
      'customRoleName': customRoleName,
      'permissions': permissions,
      'walletBalance': walletBalance,
      'walletTransactions': walletTransactions
          .map((transaction) => transaction.toMap())
          .toList(growable: false),
      'deliveryProfile': deliveryProfile?.toMap(),
      'documentUrl': documentUrl,
      'documentName': documentName,
      'rejectionReason': rejectionReason,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];

    return AppUser(
      id: map['id'] as String? ?? map['_id'] as String? ?? '',
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      role: UserRole.fromValue(map['role'] as String?),
      status: AccountStatus.fromValue(map['status'] as String?),
      createdAt: createdAtValue is String
          ? DateTime.tryParse(createdAtValue) ?? DateTime.now()
          : createdAtValue is DateTime
          ? createdAtValue
          : DateTime.now(),
      customRoleKey: map['customRoleKey'] as String?,
      customRoleName: map['customRoleName'] as String?,
      permissions: List<String>.from(map['permissions'] as List? ?? const []),
      walletBalance: (map['walletBalance'] as num? ?? 0).toInt(),
      walletTransactions: List<Map<String, dynamic>>.from(
        map['walletTransactions'] as List? ?? const [],
      ).map(UserWalletTransaction.fromMap).toList(growable: false),
      deliveryProfile: map['deliveryProfile'] is Map<String, dynamic>
          ? DeliveryProfileSnapshot.fromMap(
              map['deliveryProfile'] as Map<String, dynamic>,
            )
          : null,
      documentUrl: map['documentUrl'] as String?,
      documentName: map['documentName'] as String?,
      rejectionReason: map['rejectionReason'] as String?,
    );
  }
}

class UserWalletTransaction {
  const UserWalletTransaction({
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

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'amount': amount,
      'type': type,
      'description': description,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'orderId': orderId,
    };
  }

  factory UserWalletTransaction.fromMap(Map<String, dynamic> map) {
    return UserWalletTransaction(
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

class DeliveryProfileSnapshot {
  const DeliveryProfileSnapshot({
    required this.isOnline,
    required this.currentZone,
    required this.vehicleLabel,
    this.lastSeenAt,
  });

  final bool isOnline;
  final String currentZone;
  final String vehicleLabel;
  final DateTime? lastSeenAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'isOnline': isOnline,
      'currentZone': currentZone,
      'vehicleLabel': vehicleLabel,
      'lastSeenAt': lastSeenAt?.toIso8601String(),
    };
  }

  factory DeliveryProfileSnapshot.fromMap(Map<String, dynamic> map) {
    return DeliveryProfileSnapshot(
      isOnline: map['isOnline'] as bool? ?? false,
      currentZone: map['currentZone'] as String? ?? 'Central Zone',
      vehicleLabel: map['vehicleLabel'] as String? ?? 'Bike',
      lastSeenAt: map['lastSeenAt'] is String
          ? DateTime.tryParse(map['lastSeenAt'] as String)
          : null,
    );
  }
}
