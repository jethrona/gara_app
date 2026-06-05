import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

class ChatProvider extends ChangeNotifier {
  final ChatService _chatService = ChatService();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  List<MessageModel> _messages = [];
  int? _activeConsultationId;
  RealtimeChannel? _realtimeChannel;
  final Set<int> _pendingSending = {};

  bool get isLoading => _isLoading;
  List<MessageModel> get messages => _messages;
  int? get activeConsultationId => _activeConsultationId;
  bool get isSending => _pendingSending.isNotEmpty;

  Future<void> loadMessages(int consultationId) async {
    _isLoading = true;
    _activeConsultationId = consultationId;
    notifyListeners();

    try {
      _messages = await _chatService.getMessages(consultationId);

      _realtimeChannel?.unsubscribe();
      _realtimeChannel = _chatService.subscribeToMessages(
        consultationId: consultationId,
        onMessage: (message) {
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
            notifyListeners();
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

  void _addOptimistic(MessageModel msg) {
    _messages.add(msg);
    notifyListeners();
  }

  void _replaceOptimistic(int tempId, MessageModel real) {
    final idx = _messages.indexWhere((m) => m.id == tempId);
    if (idx != -1) {
      _messages[idx] = real;
      notifyListeners();
    }
  }

  void _removeFailed(int tempId) {
    _messages.removeWhere((m) => m.id == tempId);
    _pendingSending.remove(tempId);
    notifyListeners();
  }

  Future<void> sendTextMessage({
    required int consultationId,
    required String senderId,
    required String content,
  }) async {
    if (content.trim().isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch;
    if (_pendingSending.contains(tempId)) return;
    _pendingSending.add(tempId);

    final optimistic = MessageModel(
      id: tempId,
      consultationId: consultationId,
      senderId: senderId,
      messageType: MessageType.text,
      content: content.trim(),
      createdAt: DateTime.now(),
    );

    _addOptimistic(optimistic);

    try {
      final message = await _chatService.sendTextMessage(
        consultationId: consultationId,
        senderId: senderId,
        content: content.trim(),
      );
      _replaceOptimistic(tempId, message);
    } catch (e) {
      _removeFailed(tempId);
    } finally {
      _pendingSending.remove(tempId);
    }
  }

  Future<String?> uploadAndSendImage({
    required int consultationId,
    required String senderId,
    required Uint8List imageBytes,
    required String patientId,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch + 1;
    if (_pendingSending.contains(tempId)) return 'Already sending';
    _pendingSending.add(tempId);

    final optimistic = MessageModel(
      id: tempId,
      consultationId: consultationId,
      senderId: senderId,
      messageType: MessageType.photo,
      content: 'Uploading image...',
      createdAt: DateTime.now(),
    );

    _addOptimistic(optimistic);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _storageService.uploadImage(
        imageBytes: imageBytes,
        patientId: patientId,
        fileName: fileName,
      );

      final message = await _chatService.sendMediaMessage(
        consultationId: consultationId,
        senderId: senderId,
        type: MessageType.photo,
        storageUrl: url,
      );
      _replaceOptimistic(tempId, message);
      return null;
    } catch (e) {
      _removeFailed(tempId);
      return e.toString();
    } finally {
      _pendingSending.remove(tempId);
    }
  }

  Future<String?> uploadAndSendVoice({
    required int consultationId,
    required String senderId,
    required Uint8List voiceBytes,
    required String patientId,
    required int durationSeconds,
  }) async {
    final tempId = DateTime.now().millisecondsSinceEpoch + 2;
    if (_pendingSending.contains(tempId)) return 'Already sending';
    _pendingSending.add(tempId);

    final optimistic = MessageModel(
      id: tempId,
      consultationId: consultationId,
      senderId: senderId,
      messageType: MessageType.voice,
      content: 'Uploading voice note...',
      createdAt: DateTime.now(),
    );

    _addOptimistic(optimistic);

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.m4a';
      final url = await _storageService.uploadVoice(
        voiceBytes: voiceBytes,
        patientId: patientId,
        fileName: fileName,
      );

      final message = await _chatService.sendMediaMessage(
        consultationId: consultationId,
        senderId: senderId,
        type: MessageType.voice,
        storageUrl: url,
        durationSeconds: durationSeconds,
      );
      _replaceOptimistic(tempId, message);
      return null;
    } catch (e) {
      _removeFailed(tempId);
      return e.toString();
    } finally {
      _pendingSending.remove(tempId);
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }
}
