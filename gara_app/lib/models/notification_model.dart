class NotificationModel {
  final int? id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'info',
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String? ?? 'info',
      isRead: map['is_read'] as bool? ?? false,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'is_read': isRead,
    };
  }

  NotificationModel copyWith({
    int? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
