import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../config/theme.dart';

enum _VoiceState { idle, recording, preview, sending, error }

class VoiceRecorderWidget extends StatefulWidget {
  final Future<void> Function(Uint8List bytes, int durationSeconds) onSend;
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
  _VoiceState _state = _VoiceState.idle;
  String _errorMsg = '';

  final AudioRecorder _recorder = AudioRecorder();
  int _recSecs = 0;
  Timer? _recTimer;
  String? _recPath;
  Uint8List? _recBytes;

  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  int _positionSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _completeSub;

  late final AnimationController _pulse;
  late final Animation<double> _pulseVal;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);
    _pulseVal = Tween(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _positionSec = pos.inSeconds);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _positionSec = 0; });
    });

    _requestAndStart();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    _posSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _requestAndStart() async {
    if (kIsWeb) {
      await _startRecording();
      return;
    }
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      await _startRecording();
    } else if (status.isPermanentlyDenied) {
      _fail('Microphone permission permanently denied.\nEnable it in App Settings > GARA > Microphone.');
    } else {
      _fail('Microphone permission required.\nTap the mic button again to retry.');
    }
  }

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/gara_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

      _recPath = path;
      _recSecs = 0;
      _recTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recSecs++);
      });

      if (mounted) setState(() => _state = _VoiceState.recording);
    } catch (e) {
      _fail('Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_state != _VoiceState.recording) return;
    _recTimer?.cancel();

    try {
      final path = await _recorder.stop();
      if (path == null || path.isEmpty) {
        _fail('Recorder returned no file path.');
        return;
      }
      _recPath = path;

      Uint8List? bytes;
      if (kIsWeb && path.startsWith('blob:')) {
        final res = await http.get(Uri.parse(path));
        bytes = res.statusCode == 200 ? res.bodyBytes : null;
      } else {
        final f = io.File(path);
        bytes = f.existsSync() ? await f.readAsBytes() : null;
      }

      if (bytes == null || bytes.isEmpty) {
        _fail('Recording is empty. Try again.');
        return;
      }
      _recBytes = bytes;

      if (kIsWeb) {
        await _player.setSourceUrl(path);
      } else {
        await _player.setSourceDeviceFile(path);
      }

      if (mounted) setState(() => _state = _VoiceState.preview);
    } catch (e) {
      _fail('Failed to process recording: $e');
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
      debugPrint('VoiceRecorder playback error: $e');
    }
  }

  Future<void> _send() async {
    if (_recBytes == null || _state == _VoiceState.sending) return;
    await _player.stop();
    if (mounted) setState(() => _state = _VoiceState.sending);
    try {
      await widget.onSend(_recBytes!, _recSecs);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
        setState(() => _state = _VoiceState.preview);
      }
    }
  }

  Future<void> _cancel() async {
    if (_state == _VoiceState.sending) return;
    await _player.stop();
    _recTimer?.cancel();
    if (_state == _VoiceState.recording) {
      try { await _recorder.stop(); } catch (_) {}
    }
    _deleteTempFile();
    widget.onCancel();
  }

  Future<void> _reRecord() async {
    await _player.stop();
    _deleteTempFile();
    setState(() {
      _state = _VoiceState.idle;
      _recBytes = null;
      _recPath = null;
      _recSecs = 0;
      _isPlaying = false;
      _positionSec = 0;
    });
    await _requestAndStart();
  }

  void _deleteTempFile() {
    if (_recPath != null && !kIsWeb) {
      try { io.File(_recPath!).deleteSync(); } catch (_) {}
    }
  }

  void _fail(String msg) {
    _errorMsg = msg;
    if (mounted) setState(() => _state = _VoiceState.error);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  double get _progress =>
      _recSecs > 0 ? (_positionSec / _recSecs).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: KeyedSubtree(
        key: ValueKey(_state),
        child: _buildState(),
      ),
    );
  }

  Widget _buildState() {
    switch (_state) {
      case _VoiceState.idle:      return _buildIdle();
      case _VoiceState.recording: return _buildRecording();
      case _VoiceState.preview:   return _buildPreview();
      case _VoiceState.sending:   return _buildSending();
      case _VoiceState.error:     return _buildError();
    }
  }

  Widget _buildIdle() => _shell(
    child: Row(children: [
      const SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      const SizedBox(width: 10),
      const Expanded(child: Text('Requesting mic permission\u2026',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
      closeBtn(_cancel),
    ]),
  );

  Widget _buildRecording() => _shell(
    borderColor: AppTheme.errorRed.withValues(alpha: 0.5),
    child: Row(children: [
      closeBtn(_cancel),
      const SizedBox(width: 6),
      AnimatedBuilder(
        animation: _pulseVal,
        builder: (_, __) => Container(
          width: 9, height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.errorRed.withValues(alpha: _pulseVal.value),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('REC  ${_fmt(_recSecs)}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: AppTheme.errorRed, letterSpacing: 0.8)),
      Expanded(child: _buildWaveform()),
      GestureDetector(
        onTap: _stopRecording,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: AppTheme.errorRed,
              borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.stop_rounded, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text('Stop', style: TextStyle(
                fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]),
  );

  Widget _buildPreview() => _shell(
    borderColor: AppTheme.primaryGreen.withValues(alpha: 0.5),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded,
              color: AppTheme.textSecondary, size: 20),
          onPressed: _reRecord,
          tooltip: 'Re-record',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
                color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white, size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${_fmt(_positionSec)} / ${_fmt(_recSecs)}',
            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const Spacer(),
        GestureDetector(
          onTap: _send,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(16)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Send', style: TextStyle(
                  fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.send_rounded, color: Colors.white, size: 14),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 3,
          backgroundColor: AppTheme.borderLight,
          color: AppTheme.primaryGreen,
        ),
      ),
    ]),
  );

  Widget _buildSending() => _shell(
    borderColor: AppTheme.primaryGreen.withValues(alpha: 0.3),
    child: Row(children: [
      const SizedBox(width: 6),
      const SizedBox(width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      const SizedBox(width: 12),
      const Text('Sending voice note\u2026',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    ]),
  );

  Widget _buildError() => _shell(
    borderColor: AppTheme.errorRed.withValues(alpha: 0.5),
    bg: AppTheme.errorRed.withValues(alpha: 0.05),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Icon(Icons.mic_off_rounded, color: AppTheme.errorRed, size: 18),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(_errorMsg,
            style: const TextStyle(
                color: AppTheme.errorRed, fontSize: 12, height: 1.5)),
      ),
      TextButton(
        onPressed: widget.onCancel,
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        child: const Text('Close',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ),
    ]),
  );

  Widget _shell({required Widget child, Color? borderColor, Color? bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: bg ?? AppTheme.surfaceBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor ?? AppTheme.borderLight),
        ),
        child: child,
      );

  Widget closeBtn(VoidCallback? onTap) => IconButton(
        icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );

  static const _waveH = [4.0,8.0,12.0,16.0,9.0,5.0,14.0,7.0,16.0,
                          4.0,11.0,8.0,15.0,6.0,10.0,5.0];

  Widget _buildWaveform() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: AnimatedBuilder(
      animation: _pulseVal,
      builder: (_, __) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_waveH.length, (i) {
          final h = _waveH[i] *
              (0.4 + 0.6 * _pulseVal.value *
                  (i % 3 == 0 ? 1.0 : i % 3 == 1 ? 0.6 : 0.35));
          return Container(
            width: 2,
            height: h.clamp(2.0, 16.0),
            decoration: BoxDecoration(
              color: AppTheme.errorRed
                  .withValues(alpha: 0.4 + 0.55 * (i / _waveH.length)),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    ),
  );
}
