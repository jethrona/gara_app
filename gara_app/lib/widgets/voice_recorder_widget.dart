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
  final Future<void> Function(Uint8List voiceBytes, int durationSeconds) onSend;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onSend,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();

  int _durationSeconds = 0;
  Timer? _timer;

  bool _isRecording = false;
  bool _isSending = false;
  bool _hasError = false;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waveController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (mounted) setState(() => _hasError = true);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) widget.onCancel();
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

      _durationSeconds = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _durationSeconds = t.tick);
      });

      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('VoiceRecorder._startRecording error: $e');
      if (mounted) setState(() => _hasError = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) widget.onCancel();
    }
  }

  Future<Uint8List?> _readBytes(String path) async {
    if (kIsWeb && path.startsWith('blob:')) {
      final res = await http.get(Uri.parse(path));
      return res.statusCode == 200 ? res.bodyBytes : null;
    }
    final file = io.File(path);
    return file.existsSync() ? await file.readAsBytes() : null;
  }

  Future<void> _stopAndSend() async {
    if (!_isRecording || _isSending) return;

    _timer?.cancel();
    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        if (mounted) widget.onCancel();
        return;
      }

      final bytes = await _readBytes(path);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) widget.onCancel();
        return;
      }

      await widget.onSend(bytes, _durationSeconds);

      if (!kIsWeb) {
        final f = io.File(path);
        if (f.existsSync()) await f.delete().catchError((_) {});
      }
    } catch (e) {
      debugPrint('VoiceRecorder._stopAndSend error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice note failed: $e')),
        );
        widget.onCancel();
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _cancel() async {
    if (_isSending) return;
    _timer?.cancel();
    if (_isRecording) {
      try { await _recorder.stop(); } catch (_) {}
    }
    if (mounted) widget.onCancel();
  }

  String get _formattedTime {
    final m = (_durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorBar();
    return _buildRecorderBar();
  }

  Widget _buildErrorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mic_off_rounded, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Microphone permission denied.\nEnable it in device settings.',
              style: TextStyle(color: AppTheme.errorRed, fontSize: 12, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecorderBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isRecording ? AppTheme.errorRed.withValues(alpha: 0.4) : AppTheme.borderLight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close,
                color: _isSending ? AppTheme.textMuted : AppTheme.textSecondary, size: 20),
            onPressed: _isSending ? null : _cancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          if (_isRecording)
            AnimatedBuilder(
              animation: _waveController,
              builder: (_, __) => Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color.lerp(
                    AppTheme.errorRed,
                    AppTheme.errorRed.withValues(alpha: 0.3),
                    _waveController.value,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 8),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (_, __) => _buildWaveform(),
                ),
                const SizedBox(height: 3),
                Text(
                  _isSending ? 'Sending\u2026' : _formattedTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: _isSending ? AppTheme.primaryGreen : AppTheme.textMuted,
                    fontWeight: _isSending ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          _isSending
              ? const SizedBox(
                  width: 36, height: 36,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryGreen),
                  ),
                )
              : GestureDetector(
                  onTap: _isRecording ? _stopAndSend : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _isRecording ? AppTheme.primaryGreen : AppTheme.textMuted.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Send',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isRecording ? Colors.white : AppTheme.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.send_rounded,
                            color: _isRecording ? Colors.white : AppTheme.textMuted, size: 14),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildWaveform() {
    const barCount = 22;
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(barCount, (i) {
          final base = [3.0, 6.0, 10.0, 14.0, 9.0, 5.0, 12.0, 7.0,
                        15.0, 4.0, 11.0, 8.0, 13.0, 6.0, 10.0, 5.0,
                        14.0, 9.0, 7.0, 12.0, 4.0, 8.0][i];
          final animated = _isRecording
              ? base * (0.6 + 0.4 * _waveController.value *
                  ((i % 3 == 0) ? 1.0 : (i % 3 == 1) ? 0.7 : 0.5))
              : base * 0.4;

          return Container(
            width: 2,
            height: animated.clamp(2.0, 18.0),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: _isRecording
                  ? AppTheme.primaryGreen.withValues(alpha: 0.4 + 0.6 * (i / barCount))
                  : AppTheme.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}
