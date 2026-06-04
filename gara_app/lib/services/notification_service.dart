import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import 'supabase_service.dart';

class NotificationService {
  final SupabaseService _supabase = SupabaseService();

  Future<List<NotificationModel>> getNotifications(String userId) async {
    final response = await _supabase.client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(50);

    return (response as List).map((e) => NotificationModel.fromMap(e)).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase.client
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  Future<void> markAsRead(int notificationId) async {
    await _supabase.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
  }) async {
    final notif = NotificationModel(
      userId: userId,
      title: title,
      body: body,
      type: type,
    );

    await _supabase.client.from('notifications').insert(notif.toMap());
  }

  RealtimeChannel subscribeToNotifications({
    required String userId,
    required Function(NotificationModel) onNotification,
  }) {
    final channel = _supabase.client.channel('notifications-$userId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      table: 'notifications',
      schema: 'public',
      callback: (payload) {
        final record = payload.newRecord;
        if (record['user_id'] == userId) {
          final notification = NotificationModel.fromMap(record);
          onNotification(notification);
        }
      },
    ).subscribe();

    return channel;
  }
}
