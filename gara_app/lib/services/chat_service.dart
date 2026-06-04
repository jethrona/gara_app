import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'supabase_service.dart';

class ChatService {
  final SupabaseService _supabase = SupabaseService();

  Future<MessageModel> sendTextMessage({
    required int consultationId,
    required String senderId,
    required String content,
  }) async {
    final message = MessageModel(
      consultationId: consultationId,
      senderId: senderId,
      messageType: MessageType.text,
      content: content,
    );

    final response = await _supabase.client
        .from('messages')
        .insert(message.toMap())
        .select()
        .single();

    return MessageModel.fromMap(response);
  }

  Future<MessageModel> sendMediaMessage({
    required int consultationId,
    required String senderId,
    required MessageType type,
    required String storageUrl,
    int durationSeconds = 0,
  }) async {
    final message = MessageModel(
      consultationId: consultationId,
      senderId: senderId,
      messageType: type,
      content: storageUrl,
      durationSeconds: durationSeconds,
    );

    final response = await _supabase.client
        .from('messages')
        .insert(message.toMap())
        .select()
        .single();

    return MessageModel.fromMap(response);
  }

  Future<List<MessageModel>> getMessages(int consultationId) async {
    final response = await _supabase.client
        .from('messages')
        .select()
        .eq('consultation_id', consultationId)
        .order('created_at', ascending: true);

    return (response as List).map((e) => MessageModel.fromMap(e)).toList();
  }

  RealtimeChannel subscribeToMessages({
    required int consultationId,
    required Function(MessageModel) onMessage,
  }) {
    final channel = _supabase.client.channel('messages-$consultationId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      table: 'messages',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['consultation_id'] == consultationId) {
          final message = MessageModel.fromMap(record);
          onMessage(message);
        }
      },
    ).subscribe();

    return channel;
  }
}
