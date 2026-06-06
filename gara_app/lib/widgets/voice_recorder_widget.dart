import 'dart:async';
import 'dart:io' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/theme.dart';

enum _VoiceState { idle, requesting, recording, preview, sending, error }

class VoiceMicButton extends StatefulWidget {
  final Future<void> Function(Uint8List bytes, int durationSeconds) onSend;

  const VoiceMicButton({super.key, required this.onSend});

  @override
  State<VoiceMicButton> createState() => _VoiceMicButtonState();
}

class _VoiceMicButtonState extends State<VoiceMicButton>
    with SingleTickerProviderStateMixin {
  _VoiceState _state = _VoiceState.idle;
  String _errorMsg = '';

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _recorderReady = false;
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
    if (_recorderReady) { _recorder.closeRecorder(); _recorderReady = false; }
    _posSub?.cancel();
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _requestAndStart() async {
    setState(() => _state = _VoiceState.requesting);

    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      _fail('Microphone permission was permanently denied.\n'
          'Go to Settings \u2192 Apps \u2192 GARA \u2192 Permissions\n'
          'and enable Microphone, then try again.',
          showSettings: true);
      return;
    }

    if (!status.isGranted) {
      _fail('Microphone permission is required to record voice notes.');
      return;
    }

    try {
      await _recorder.openRecorder();
      _recorderReady = true;
    } catch (e) {
      _fail('Could not open audio session: $e');
      return;
    }

    await _startRecording();
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/gara_voice_${DateTime.now().millisecondsSinceEpoch}.aac';

      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.aacADTS,
        bitRate: 64000,
        sampleRate: 44100,
      );

      _recPath = path;
      _recSecs = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });

      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _state = _VoiceState.recording);
    } catch (e) {
      debugPrint('[VoiceMic] startRecorder error: $e');
      _fail('Failed to start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_state != _VoiceState.recording) return;
    _recTimer?.cancel();
    HapticFeedback.lightImpact();

    try {
      await _recorder.stopRecorder();
      await _recorder.closeRecorder();
      _recorderReady = false;

      if (_recPath == null) { _reset(); return; }

      final file = io.File(_recPath!);
      if (!file.existsSync()) {
        _fail('Recording file not found. Try again.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        _fail('Recording was empty. Check microphone and try again.');
        return;
      }

      _recBytes = bytes;

      await _player.setSourceDeviceFile(_recPath!);

      if (mounted) setState(() { _state = _VoiceState.preview; _progress = 0; _posSec = 0; });
    } catch (e) {
      debugPrint('[VoiceMic] stopRecorder error: $e');
      _fail('Error stopping recording: $e');
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
    } catch (e) {
      debugPrint('[VoiceMic] playback error: $e');
    }
  }

  Future<void> _send() async {
    if (_recBytes == null || _state == _VoiceState.sending) return;
    await _player.stop();
    final bytes = _recBytes!;
    final dur = _recSecs;
    setState(() => _state = _VoiceState.sending);

    try {
      await widget.onSend(bytes, dur);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e')),
        );
        setState(() => _state = _VoiceState.preview);
        return;
      }
    }
    _deleteTmp();
    _reset();
  }

  Future<void> _discard() async {
    await _player.stop();
    _deleteTmp();
    _reset();
  }

  Future<void> _cancelRecording() async {
    _recTimer?.cancel();
    try {
      if (_recorderReady) {
        await _recorder.stopRecorder();
        await _recorder.closeRecorder();
        _recorderReady = false;
      }
    } catch (_) {}
    _deleteTmp();
    _reset();
  }

  void _reset() {
    if (mounted) {
      setState(() {
        _state = _VoiceState.idle;
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

  void _fail(String msg, {bool showSettings = false}) {
    _errorMsg = msg;
    if (mounted) setState(() => _state = _VoiceState.error);
    if (showSettings) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mic permission permanently denied'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
          duration: const Duration(seconds: 6),
        ));
      });
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _VoiceState.idle:      return _buildMicBtn();
      case _VoiceState.requesting: return _buildRequestingBar();
      case _VoiceState.recording: return _buildRecordingBar();
      case _VoiceState.preview:   return _buildPreviewBar();
      case _VoiceState.sending:   return _buildSendingBar();
      case _VoiceState.error:     return _buildErrorBar();
    }
  }

  Widget _buildMicBtn() => GestureDetector(
    onTap: _requestAndStart,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Icon(Icons.mic_rounded, color: AppTheme.textSecondary, size: 22),
    ),
  );

  Widget _buildRequestingBar() => _shell(
    child: Row(children: [
      const SizedBox(width: 6),
      const SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      const SizedBox(width: 10),
      const Expanded(
        child: Text('Requesting microphone permission\u2026',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
    ]),
  );

  Widget _buildRecordingBar() => _shell(
    border: AppTheme.errorRed.withValues(alpha: 0.5),
    child: Row(children: [
      GestureDetector(
        onTap: _cancelRecording,
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
        style: const TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700,
          color: AppTheme.errorRed, letterSpacing: 1.0)),
      Expanded(child: _WaveformBars(tick: _recSecs)),
      GestureDetector(
        onTap: _stopRecording,
        child: Container(
          width: 42, height: 42,
          decoration: const BoxDecoration(
            color: AppTheme.primaryGreen, shape: BoxShape.circle),
          child: const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
        ),
      ),
    ]),
  );

  Widget _buildPreviewBar() => _shell(
    border: AppTheme.primaryGreen.withValues(alpha: 0.5),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        GestureDetector(
          onTap: _discard,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.delete_outline_rounded,
                color: AppTheme.textSecondary, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Text(_fmt(_posSec),
          style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen,
              fontWeight: FontWeight.w600)),
        Text(' / ${_fmt(_recSecs)}',
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        GestureDetector(
          onTap: _send,
          child: Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
          activeTrackColor: AppTheme.primaryGreen,
          inactiveTrackColor: AppTheme.borderLight,
          thumbColor: AppTheme.primaryGreen,
          overlayColor: AppTheme.primaryGreen.withValues(alpha: 0.15),
        ),
        child: Slider(
          value: _progress,
          onChanged: (v) async {
            final ms = (v * _recSecs * 1000).round();
            await _player.seek(Duration(milliseconds: ms));
            if (mounted) setState(() => _progress = v);
          },
        ),
      ),
    ]),
  );

  Widget _buildSendingBar() => _shell(
    border: AppTheme.primaryGreen.withValues(alpha: 0.3),
    child: const Row(children: [
      SizedBox(width: 8),
      SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      SizedBox(width: 12),
      Text('Sending voice note\u2026',
        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    ]),
  );

  Widget _buildErrorBar() => _shell(
    border: AppTheme.errorRed.withValues(alpha: 0.5),
    bg: AppTheme.errorRed.withValues(alpha: 0.05),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 2),
        child: Icon(Icons.mic_off_rounded, color: AppTheme.errorRed, size: 18)),
      const SizedBox(width: 8),
      Expanded(
        child: Text(_errorMsg,
          style: const TextStyle(color: AppTheme.errorRed, fontSize: 12, height: 1.5))),
      TextButton(
        onPressed: _reset,
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: const Text('Retry', style: TextStyle(fontSize: 12))),
      TextButton(
        onPressed: () { _deleteTmp(); _reset(); },
        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
        child: const Text('Close',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
    ]),
  );

  Widget _shell({required Widget child, Color? border, Color? bg}) =>
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border ?? AppTheme.borderLight),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: child,
      );
}

class _WaveformBars extends StatelessWidget {
  final int tick;
  const _WaveformBars({required this.tick});

  static const _h = [
    0.25, 0.55, 1.0, 0.70, 0.40, 0.85, 0.50, 0.75,
    0.30, 0.65, 1.0, 0.45, 0.60, 0.90, 0.50, 0.35,
    0.80, 0.60, 1.0, 0.40, 0.70, 0.55, 0.90, 0.30,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_h.length, (i) {
          final active = (i + tick) % 3 != 0;
          final height = (_h[i] * 22).clamp(3.0, 22.0);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 2.5,
            height: active ? height : height * 0.35,
            decoration: BoxDecoration(
              color: active
                  ? AppTheme.errorRed.withValues(alpha: 0.55 + 0.45 * _h[i])
                  : AppTheme.errorRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
