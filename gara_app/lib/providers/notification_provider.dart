import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  String? _userId;
  RealtimeChannel? _realtimeChannel;
  VoidCallback? _onPaymentReceived;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void setOnPaymentReceived(VoidCallback callback) {
    _onPaymentReceived = callback;
  }

  Future<void> init(String userId) async {
    _userId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      _notifications = await _service.getNotifications(userId);
      _unreadCount = _notifications.where((n) => !n.isRead).length;

      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _service.subscribeToNotifications(
        userId: userId,
        onNotification: (notif) {
          _notifications.insert(0, notif);
          if (!notif.isRead) _unreadCount++;
          notifyListeners();
          if (notif.type == 'payment' && _onPaymentReceived != null) {
            _onPaymentReceived!();
          }
        },
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int id) async {
    await _service.markAsRead(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _unreadCount = (_unreadCount - 1).clamp(0, _notifications.length);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_userId == null) return;
    await _service.markAllAsRead(_userId!);
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'info',
    int? consultationId,
  }) async {
    await _service.createNotification(
      userId: userId,
      title: title,
      body: body,
      type: type,
      consultationId: consultationId,
    );
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
