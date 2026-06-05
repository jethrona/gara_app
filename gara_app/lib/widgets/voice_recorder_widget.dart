import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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
  int _durationSeconds = 0;
  Timer? _timer;
  bool _isRecording = false;
  bool _hasError = false;
  String? _recordedPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _hasError = true;
        if (mounted) setState(() {});
        widget.onCancel();
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (kIsWeb) {
        await _recorder.start(const RecordConfig(), path: path);
      } else {
        await _recorder.start(
          RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
          path: path,
        );
      }
      _recordedPath = path;

      _durationSeconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _durationSeconds = t.tick);
      });
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('VoiceRecorder start error: $e');
      _hasError = true;
      if (mounted) setState(() {});
      widget.onCancel();
    }
  }

  Future<Uint8List?> _readBytes(String path) async {
    if (kIsWeb && path.startsWith('blob:')) {
      final response = await http.get(Uri.parse(path));
      if (response.statusCode == 200) return response.bodyBytes;
      return null;
    }
    final file = io.File(path);
    if (file.existsSync()) return file.readAsBytes();
    return null;
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording) return;
    _timer?.cancel();
    setState(() => _isRecording = false);

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        widget.onCancel();
        return;
      }
      _recordedPath = path;
      final bytes = await _readBytes(path);
      if (bytes != null && bytes.isNotEmpty) {
        widget.onSend(bytes, _durationSeconds);
        return;
      }
    } catch (e) {
      debugPrint('VoiceRecorder stop error: $e');
    }
    widget.onCancel();
  }

  Future<void> _cancel() async {
    _timer?.cancel();
    if (_isRecording) {
      try { await _recorder.stop(); } catch (_) {}
    }
    widget.onCancel();
  }

  String _formatDuration(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            const Icon(Icons.mic_off_rounded, color: AppTheme.errorRed, size: 20),
            const SizedBox(width: 8),
            const Text('Mic unavailable', style: TextStyle(color: AppTheme.errorRed, fontSize: 13)),
            const Spacer(),
            GestureDetector(
              onTap: widget.onCancel,
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
            onPressed: _cancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.errorRed),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Row(
                    children: List.generate(20, (i) => Container(
                      width: 2, height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      color: i % 2 == _durationSeconds % 2
                          ? AppTheme.primaryGreen
                          : AppTheme.primaryGreen.withValues(alpha: 0.25),
                    )),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(_durationSeconds),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isRecording ? _stopAndSend : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _isRecording ? AppTheme.primaryGreen : AppTheme.textMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Send', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.send_rounded, color: Colors.white, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
