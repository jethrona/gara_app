class NotificationModel {
  final int? id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime? createdAt;
  final int? consultationId;

  NotificationModel({
    this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type = 'info',
    this.isRead = false,
    this.createdAt,
    this.consultationId,
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
      consultationId: map['consultation_id'] as int?,
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
      if (consultationId != null) 'consultation_id': consultationId,
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
    int? consultationId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      consultationId: consultationId ?? this.consultationId,
    );
  }
}
