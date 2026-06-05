import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/theme.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final void Function(Uint8List voiceBytes, int durationSeconds) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  String? _recordedPath;
  int _durationSeconds = 0;
  Timer? _timer;
  bool _isPreviewing = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      widget.onCancel();
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
      path: path,
    );
    _durationSeconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _durationSeconds = t.tick);
    });
    setState(() {});
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stop();
    if (path != null) {
      _recordedPath = path;
      _isPreviewing = true;
      setState(() {});
    } else {
      widget.onCancel();
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordedPath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      await _player.stop();
      await _player.setSourceDeviceFile(_recordedPath!);
      _player.onPlayerComplete.listen((_) {
        setState(() => _isPlaying = false);
      });
      await _player.resume();
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: _isPreviewing ? _buildPreview() : _buildRecording(),
    );
  }

  Widget _buildRecording() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.errorRed),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(_durationSeconds),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        const SizedBox(width: 8),
        Container(
          width: 100, height: 4,
          decoration: BoxDecoration(
            color: AppTheme.borderLight,
            borderRadius: BorderRadius.circular(2),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (_, v, __) => LayoutBuilder(
              builder: (_, constraints) => Row(
                children: List.generate(20, (i) => Container(
                  width: 2, height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  color: (i % 3 == _durationSeconds % 3)
                      ? AppTheme.primaryGreen
                      : AppTheme.primaryGreen.withValues(alpha: 0.3),
                )),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _stopRecording,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppTheme.errorRed,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlayback,
          child: Icon(
            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
            color: AppTheme.primaryGreen,
            size: 28,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 80, height: 4,
          decoration: BoxDecoration(
            color: AppTheme.borderLight,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: List.generate(20, (i) => Container(
              width: 2, height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              color: i < (_durationSeconds * 20 ~/ 60).clamp(0, 20)
                  ? AppTheme.primaryGreen
                  : AppTheme.primaryGreen.withValues(alpha: 0.15),
            )),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(_durationSeconds),
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => widget.onCancel(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Delete', style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () async {
            if (_recordedPath != null) {
              final file = io.File(_recordedPath!);
              final bytes = await file.readAsBytes();
              widget.onSend(bytes, _durationSeconds);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('Send', style: TextStyle(fontSize: 12, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
