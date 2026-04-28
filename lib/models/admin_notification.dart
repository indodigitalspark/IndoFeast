class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.targetRoles,
    required this.isRead,
    this.relatedUserId,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final List<String> targetRoles;
  final bool isRead;
  final String? relatedUserId;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'body': body,
      'createdAt': createdAt.toIso8601String(),
      'targetRoles': targetRoles,
      'isRead': isRead,
      'relatedUserId': relatedUserId,
    };
  }

  factory AdminNotification.fromMap(String id, Map<String, dynamic> map) {
    final createdAtValue = map['createdAt'];

    return AdminNotification(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: createdAtValue is String
          ? DateTime.tryParse(createdAtValue) ?? DateTime.now()
          : createdAtValue is DateTime
          ? createdAtValue
          : DateTime.now(),
      targetRoles: List<String>.from(map['targetRoles'] as List? ?? const []),
      isRead: map['isRead'] as bool? ?? false,
      relatedUserId: map['relatedUserId'] as String?,
    );
  }
}
