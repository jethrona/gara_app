import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';

String _detectExtension(Uint8List bytes) {
  if (bytes.length < 4) return 'm4a';
  // WebM / Matroska: 0x1A 0x45 0xDF 0xA3
  if (bytes[0] == 0x1A && bytes[1] == 0x45 && bytes[2] == 0xDF && bytes[3] == 0xA3) return 'webm';
  // Ogg: 0x4F 0x67 0x67 0x53
  if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) return 'ogg';
  // RIFF (WAV): 0x52 0x49 0x46 0x46
  if (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) return 'wav';
  return 'm4a';
}

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

      final prev = _realtimeChannel;
      _realtimeChannel = null;
      if (prev != null) await prev.unsubscribe();

      final channel = _chatService.subscribeToMessages(
        consultationId: consultationId,
        onMessage: (message) {
          if (_activeConsultationId != consultationId) return;
          if (!_messages.any((m) => m.id == message.id)) {
            _messages.add(message);
            notifyListeners();
          }
        },
      );
      _realtimeChannel = channel;

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
      final url = await _storageService.uploadImage(
        imageBytes: imageBytes,
        patientId: senderId,
        fileName: 'img.jpg',
      );

      final message = await _chatService.sendMediaMessage(
        consultationId: consultationId,
        senderId: senderId,
        type: MessageType.photo,
        mediaUrl: url,
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
      content: 'Uploading voice...',
      createdAt: DateTime.now(),
    );

    _addOptimistic(optimistic);

    try {
      final ext = _detectExtension(voiceBytes);
      final url = await _storageService.uploadVoice(
        voiceBytes: voiceBytes,
        patientId: senderId,
        fileName: 'voice.$ext',
      );

      final message = await _chatService.sendMediaMessage(
        consultationId: consultationId,
        senderId: senderId,
        type: MessageType.voice,
        mediaUrl: url,
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
