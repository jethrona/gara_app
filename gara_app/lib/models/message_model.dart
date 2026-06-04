enum MessageType { text, voice, photo }

class MessageModel {
  final int? id;
  final int consultationId;
  final String senderId;
  final MessageType messageType;
  final String content;
  final int durationSeconds;
  final DateTime? createdAt;

  MessageModel({
    this.id,
    required this.consultationId,
    required this.senderId,
    required this.messageType,
    required this.content,
    this.durationSeconds = 0,
    this.createdAt,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as int?,
      consultationId: map['consultation_id'] as int,
      senderId: map['sender_id'] as String,
      messageType: _parseType(map['message_type'] as String),
      content: map['content'] as String,
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'consultation_id': consultationId,
      'sender_id': senderId,
      'message_type': _typeToString(messageType),
      'content': content,
      'duration_seconds': durationSeconds,
    };
  }

  static MessageType _parseType(String type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'voice':
        return MessageType.voice;
      case 'photo':
        return MessageType.photo;
      default:
        return MessageType.text;
    }
  }

  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.voice:
        return 'voice';
      case MessageType.photo:
        return 'photo';
    }
  }
}
