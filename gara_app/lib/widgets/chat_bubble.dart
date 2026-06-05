import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/message_model.dart';

class ChatBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const ChatBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _buildAvatar(),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              padding: _getPadding(),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildContent(),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
          if (isMe) _buildAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: isMe ? AppTheme.primaryGreen.withValues(alpha: 0.1) : AppTheme.accentBlue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isMe ? Icons.person_rounded : Icons.medical_services_rounded,
        size: 16,
        color: isMe ? AppTheme.primaryGreen : AppTheme.accentBlue,
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (message.messageType) {
      case MessageType.text:
        return const EdgeInsets.symmetric(horizontal: 14, vertical: 10);
      case MessageType.photo:
        return const EdgeInsets.all(4);
      case MessageType.voice:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    }
  }

  Widget _buildContent() {
    switch (message.messageType) {
      case MessageType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: isMe ? Colors.white : AppTheme.textPrimary,
                height: 1.3,
              ),
            ),
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '${message.createdAt!.hour.toString().padLeft(2, '0')}:${message.createdAt!.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textMuted,
                ),
              ),
            ],
          ],
        );

      case MessageType.photo:
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: CachedNetworkImage(
            imageUrl: message.content,
            placeholder: (_, __) => Container(
              height: 150,
              color: AppTheme.surfaceBg,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 150,
              color: AppTheme.surfaceBg,
              child: const Icon(Icons.broken_image_rounded, color: AppTheme.textMuted),
            ),
            fit: BoxFit.cover,
          ),
        );

      case MessageType.voice:
        return _VoicePlayer(message: message, isMe: isMe);
    }
  }
}

class _VoicePlayer extends StatefulWidget {
  final MessageModel message;
  final bool isMe;
  const _VoicePlayer({required this.message, required this.isMe});

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_isPlaying) {
      await _player.pause();
      if (mounted) setState(() => _isPlaying = false);
      return;
    }

    try {
      _hasError = false;
      await _player.stop();
      await _player.setSourceUrl(widget.message.content);
      await _player.resume();
      if (mounted) setState(() => _isPlaying = true);
    } catch (_) {
      if (mounted) setState(() { _isPlaying = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.isMe ? Colors.white : AppTheme.primaryGreen;
    return GestureDetector(
      onTap: _hasError ? null : _play,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasError ? Icons.error_outline_rounded :
            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            color: _hasError ? AppTheme.errorRed : iconColor,
            size: 28,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isMe ? Colors.white.withValues(alpha: 0.4) : AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: List.generate(20, (i) => Container(
                    width: 2,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: widget.isMe ? Colors.white.withValues(alpha: 0.7 + (i * 0.015)) : AppTheme.primaryGreen.withValues(alpha: 0.3 + (i * 0.035)),
                  )),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _hasError ? 'error' : '${widget.message.durationSeconds}s',
                style: TextStyle(fontSize: 11, color: widget.isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
