import 'dart:async';
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/theme.dart';

class VoiceMicButton extends StatefulWidget {
  final Future<void> Function(Uint8List bytes, int durationSeconds) onSend;

  const VoiceMicButton({super.key, required this.onSend});

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

enum _VMS { idle, recording, preview, sending }

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  _VMS _mode = _VMS.idle;

  final AudioRecorder _recorder = AudioRecorder();
  int _recSecs = 0;
  Timer? _recTimer;
  String? _recPath;
  Uint8List? _recBytes;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  double _progress = 0;
  int _posSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _doneSub;

  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final total = _recSecs > 0 ? _recSecs : 1;
      setState(() {
        _posSec = pos.inSeconds;
        _progress = (pos.inSeconds / total).clamp(0.0, 1.0);
      });
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _progress = 0; _posSec = 0; });
    });
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    _posSub?.cancel();
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/gara_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        kIsWeb
            ? const RecordConfig()
            : const RecordConfig(
                encoder: AudioEncoder.aacLc,
                bitRate: 64000,
                sampleRate: 44100,
              ),
        path: path,
      );

      final isRecording = await _recorder.isRecording();
      if (!isRecording) {
        if (mounted) _showPermissionError();
        return;
      }

      _recPath = path;
      _recSecs = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });

      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _mode = _VMS.recording);
    } catch (e) {
      debugPrint('[Voice] start error: $e');
      if (mounted) _showPermissionError();
    }
  }

  Future<void> _stopRecording() async {
    _recTimer?.cancel();
    HapticFeedback.lightImpact();

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) { _reset(); return; }
      _recPath = path;

      Uint8List? bytes;
      if (kIsWeb && path.startsWith('blob:')) {
        final res = await http.get(Uri.parse(path));
        bytes = res.statusCode == 200 ? res.bodyBytes : null;
      } else {
        final f = io.File(path);
        bytes = f.existsSync() ? await f.readAsBytes() : null;
      }

      if (bytes == null || bytes.isEmpty) { _reset(); return; }
      _recBytes = bytes;

      if (!kIsWeb) {
        await _player.setSourceDeviceFile(path);
      } else {
        await _player.setSourceUrl(path);
      }

      if (mounted) setState(() { _mode = _VMS.preview; _progress = 0; _posSec = 0; });
    } catch (e) {
      debugPrint('[Voice] stop error: $e');
      _reset();
    }
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player.resume();
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (_) {}
  }

  Future<void> _send() async {
    if (_recBytes == null) return;
    await _player.stop();
    final bytes = _recBytes!;
    final dur = _recSecs;
    setState(() => _mode = _VMS.sending);

    try {
      await widget.onSend(bytes, dur);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
      }
    }
    _reset();
  }

  void _discard() {
    _player.stop();
    _deleteTmp();
    _reset();
  }

  void _reset() {
    _recTimer?.cancel();
    if (mounted) {
      setState(() {
        _mode = _VMS.idle;
        _recBytes = null;
        _recPath = null;
        _recSecs = 0;
        _isPlaying = false;
        _progress = 0;
        _posSec = 0;
      });
    }
  }

  void _deleteTmp() {
    if (_recPath != null && !kIsWeb) {
      try { io.File(_recPath!).deleteSync(); } catch (_) {}
    }
  }

  void _showPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Microphone permission required.\n'
          'Go to Settings \u2192 App Permissions \u2192 GARA and enable Microphone.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    switch (_mode) {
      case _VMS.idle:      return _buildMicBtn();
      case _VMS.recording: return _buildRecordingBar();
      case _VMS.preview:   return _buildPreviewBar();
      case _VMS.sending:   return _buildSendingBar();
    }
  }

  Widget _buildMicBtn() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.mic_rounded, color: AppTheme.textSecondary, size: 22),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () async {
              _recTimer?.cancel();
              try { await _recorder.stop(); } catch (_) {}
              _deleteTmp();
              _reset();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) => Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.errorRed.withValues(alpha: 0.3 + 0.7 * _pulse.value),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(_fmt(_recSecs),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: AppTheme.errorRed, letterSpacing: 1.0)),
          Expanded(child: _WaveformWidget(tick: _recSecs)),
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
              child: const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.4)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          GestureDetector(
            onTap: _discard,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.textSecondary, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_fmt(_posSec),
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
          Text(' / ${_fmt(_recSecs)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const Spacer(),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(color: AppTheme.primaryGreen, shape: BoxShape.circle),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: AppTheme.primaryGreen,
            inactiveTrackColor: AppTheme.borderLight,
            thumbColor: AppTheme.primaryGreen,
            overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: _progress,
            onChanged: (v) async {
              final seekMs = (v * _recSecs * 1000).round();
              await _player.seek(Duration(milliseconds: seekMs));
              setState(() => _progress = v);
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildSendingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: const Row(children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
        SizedBox(width: 12),
        Text('Sending voice note\u2026',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ]),
    );
  }
}

class _WaveformWidget extends StatelessWidget {
  final int tick;
  const _WaveformWidget({required this.tick});

  static const _pattern = [
    0.3, 0.6, 1.0, 0.7, 0.4, 0.9, 0.5, 0.8,
    0.3, 0.7, 1.0, 0.4, 0.6, 0.9, 0.5, 0.3,
    0.8, 0.6, 1.0, 0.4, 0.7, 0.5, 0.9, 0.3,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_pattern.length, (i) {
          final active = (i + tick) % 3 != 0;
          final h = (_pattern[i] * 20).clamp(3.0, 20.0);
          return Container(
            width: 2.5,
            height: active ? h : h * 0.4,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.errorRed.withValues(alpha: 0.7)
                  : AppTheme.errorRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
