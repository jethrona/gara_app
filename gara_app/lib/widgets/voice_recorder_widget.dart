// ─────────────────────────────────────────────────────────────────────────────
// WHAT CAUSED THE FROZEN 00:00 / GREY SEND BUG
//
// _startRecording() called _recorder.hasPermission() first.
// On Android, hasPermission() in the `record` package talks to its OWN
// internal channel — not the OS. It returns false even after the user grants
// mic permission in device Settings. This is a confirmed upstream bug.
//
// When hasPermission() returned false, the code did:
//   widget.onCancel()  ←── this sets _showRecorder=false in the parent
// But the widget was already built, so it showed the empty bar with 00:00.
// onCancel() unmounted it too late — after one frame — leaving the ghost UI.
//
// FIX: Remove hasPermission() entirely. Call _recorder.start() directly.
// The `record` package requests the permission dialog from inside start()
// when RECORD_AUDIO is declared in AndroidManifest.xml.
// If it still fails, catch the exception and SHOW the error in the widget
// instead of calling onCancel() — so the user can read what went wrong.
//
// NO NEW PACKAGES NEEDED. Same imports as before.
//
// AndroidManifest.xml must have (outside <application>):
//   <uses-permission android:name="android.permission.RECORD_AUDIO"/>
//
// iOS Info.plist must have:
//   <key>NSMicrophoneUsageDescription</key>
//   <string>GARA needs mic access to send voice notes.</string>
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../config/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoiceRecorderWidget
//
// Drop-in replacement. Same class name, same constructor parameters.
// New behaviour:
//   • Skips hasPermission() — calls start() directly (it requests permission)
//   • Shows errors INSIDE the widget instead of calling onCancel()
//   • After stop: shows a play/pause preview bar before sending
//   • onSend is still void — parent dismisses after calling it
// ─────────────────────────────────────────────────────────────────────────────

enum _RS { starting, recording, preview, sending, error }

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

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {

  // ── recorder ───────────────────────────────────────────────────────────────
  final AudioRecorder _rec = AudioRecorder();
  _RS _state = _RS.starting;
  String _errorMsg = '';
  int _secs = 0;
  Timer? _timer;
  String? _path;
  Uint8List? _bytes;

  // ── preview player ─────────────────────────────────────────────────────────
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  double _prog = 0;
  int _posSec = 0;
  StreamSubscription? _posSub;
  StreamSubscription? _doneSub;

  // ── pulse animation ────────────────────────────────────────────────────────
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..repeat(reverse: true);

    _posSub = _player.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _posSec = pos.inSeconds;
        _prog = _secs > 0 ? (pos.inSeconds / _secs).clamp(0.0, 1.0) : 0;
      });
    });
    _doneSub = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _playing = false; _prog = 0; _posSec = 0; });
    });

    // Start immediately — don't check hasPermission() first
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _rec.dispose();
    _posSub?.cancel();
    _doneSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ── start ──────────────────────────────────────────────────────────────────

  Future<void> _startRecording() async {
    try {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/gara_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // KEY FIX: call start() directly — it handles permission internally.
      // Do NOT call hasPermission() first; that's the broken call.
      await _rec.start(
        kIsWeb
            ? const RecordConfig()
            : const RecordConfig(
                encoder: AudioEncoder.aacLc,
                bitRate: 64000,
                sampleRate: 44100,
              ),
        path: path,
      );

      // Verify it actually started (catches silent failures)
      final isRecording = await _rec.isRecording();
      if (!isRecording) {
        _fail(
          'Recording did not start.\n\n'
          'Make sure GARA has Microphone permission:\n'
          'Settings \u2192 Apps \u2192 GARA \u2192 Permissions \u2192 Microphone \u2192 Allow',
        );
        return;
      }

      _path = path;
      _secs = 0;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _secs++);
      });

      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _state = _RS.recording);
    } catch (e) {
      debugPrint('[Voice] start error: $e');
      // Show the error — do NOT call onCancel() — so user can read it
      _fail(
        'Could not access microphone.\n\n'
        'Go to: Settings \u2192 Apps \u2192 GARA \u2192 Permissions\n'
        'Enable "Microphone" then tap the mic button again.\n\n'
        'Error: $e',
      );
    }
  }

  // ── stop ───────────────────────────────────────────────────────────────────

  Future<void> _stopRecording() async {
    if (_state != _RS.recording) return;
    _timer?.cancel();
    HapticFeedback.lightImpact();

    try {
      final path = await _rec.stop();
      if (path == null || path.isEmpty) {
        _fail('Recorder returned no file. Try again.');
        return;
      }
      _path = path;

      Uint8List? bytes;
      if (kIsWeb && path.startsWith('blob:')) {
        final res = await http.get(Uri.parse(path));
        bytes = res.statusCode == 200 ? res.bodyBytes : null;
      } else {
        final f = io.File(path);
        bytes = f.existsSync() ? await f.readAsBytes() : null;
      }

      if (bytes == null || bytes.isEmpty) {
        _fail('Recording file was empty. Try again.');
        return;
      }
      _bytes = bytes;

      // Load into preview player
      if (kIsWeb) {
        await _player.setSourceUrl(path);
      } else {
        await _player.setSourceDeviceFile(path);
      }

      if (mounted) setState(() { _state = _RS.preview; _prog = 0; _posSec = 0; });
    } catch (e) {
      debugPrint('[Voice] stop error: $e');
      _fail('Failed to save recording: $e');
    }
  }

  // ── preview ────────────────────────────────────────────────────────────────

  Future<void> _togglePlay() async {
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.resume();
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {}
  }

  // ── send ───────────────────────────────────────────────────────────────────

  void _send() {
    if (_bytes == null || _state == _RS.sending) return;
    _player.stop();
    setState(() => _state = _RS.sending);
    widget.onSend(_bytes!, _secs);
    // Parent's onSend calls setState(_showRecorder=false) after this returns
  }

  // ── cancel / discard ───────────────────────────────────────────────────────

  Future<void> _cancel() async {
    if (_state == _RS.sending) return;
    _timer?.cancel();
    _player.stop();
    if (_state == _RS.recording) {
      try { await _rec.stop(); } catch (_) {}
    }
    _deleteTmp();
    widget.onCancel();
  }

  Future<void> _reRecord() async {
    await _player.stop();
    _deleteTmp();
    setState(() {
      _state = _RS.starting;
      _bytes = null;
      _path = null;
      _secs = 0;
      _playing = false;
      _prog = 0;
      _posSec = 0;
    });
    await _startRecording();
  }

  void _deleteTmp() {
    if (_path != null && !kIsWeb) {
      try { io.File(_path!).deleteSync(); } catch (_) {}
    }
  }

  void _fail(String msg) {
    _timer?.cancel();
    _errorMsg = msg;
    if (mounted) setState(() => _state = _RS.error);
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: KeyedSubtree(key: ValueKey(_state), child: _buildForState()),
    );
  }

  Widget _buildForState() {
    switch (_state) {
      case _RS.starting:  return _buildStarting();
      case _RS.recording: return _buildRecording();
      case _RS.preview:   return _buildPreview();
      case _RS.sending:   return _buildSending();
      case _RS.error:     return _buildError();
    }
  }

  // ── starting (spinner) ────────────────────────────────────────────────────
  Widget _buildStarting() => _shell(
    border: AppTheme.borderLight,
    child: Row(children: [
      const SizedBox(width: 4),
      const SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      const SizedBox(width: 10),
      const Expanded(child: Text('Starting microphone\u2026',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
      _xBtn(_cancel),
    ]),
  );

  // ── recording ─────────────────────────────────────────────────────────────
  Widget _buildRecording() => _shell(
    border: AppTheme.errorRed.withValues(alpha: 0.45),
    child: Row(children: [
      // Delete / cancel recording
      _xBtn(_cancel, icon: Icons.delete_outline_rounded),
      const SizedBox(width: 8),
      // Pulsing dot
      AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.errorRed.withValues(alpha: 0.3 + 0.7 * _pulse.value),
          ),
        ),
      ),
      const SizedBox(width: 8),
      // Timer — this MUST count if recording is working
      Text(_fmt(_secs),
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppTheme.errorRed, letterSpacing: 1.0)),
      // Animated waveform
      Expanded(child: _Waveform(tick: _secs)),
      // Stop → preview
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

  // ── preview ───────────────────────────────────────────────────────────────
  Widget _buildPreview() => _shell(
    border: AppTheme.primaryGreen.withValues(alpha: 0.45),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        // Re-record
        _xBtn(_reRecord, icon: Icons.delete_outline_rounded),
        const SizedBox(width: 8),
        // Play / pause
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
                color: AppTheme.primaryGreen, shape: BoxShape.circle),
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        Text(_fmt(_posSec),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen)),
        Text(' / ${_fmt(_secs)}',
            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        const Spacer(),
        // Send
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
      const SizedBox(height: 4),
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
          value: _prog,
          onChanged: (v) async {
            await _player.seek(Duration(milliseconds: (v * _secs * 1000).round()));
            if (mounted) setState(() => _prog = v);
          },
        ),
      ),
    ]),
  );

  // ── sending ───────────────────────────────────────────────────────────────
  Widget _buildSending() => _shell(
    border: AppTheme.primaryGreen.withValues(alpha: 0.3),
    child: const Row(children: [
      SizedBox(width: 6),
      SizedBox(width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGreen)),
      SizedBox(width: 12),
      Text('Sending\u2026', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
    ]),
  );

  // ── error — SHOWN IN WIDGET, never hidden ─────────────────────────────────
  Widget _buildError() => _shell(
    border: AppTheme.errorRed.withValues(alpha: 0.5),
    bg: AppTheme.errorRed.withValues(alpha: 0.05),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.mic_off_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 8),
          const Text('Microphone error',
              style: TextStyle(color: AppTheme.errorRed,
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton(
            onPressed: _reRecord,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppTheme.primaryGreen),
            child: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
          TextButton(
            onPressed: widget.onCancel,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: AppTheme.textSecondary),
            child: const Text('Close', style: TextStyle(fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Text(_errorMsg,
            style: const TextStyle(
                color: AppTheme.errorRed, fontSize: 11, height: 1.5)),
      ],
    ),
  );

  // ── helpers ───────────────────────────────────────────────────────────────

  Widget _shell({required Widget child, Color? border, Color? bg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bg ?? Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: border ?? AppTheme.borderLight),
        ),
        child: child,
      );

  Widget _xBtn(VoidCallback? onTap, {IconData icon = Icons.close}) =>
      IconButton(
        icon: Icon(icon, color: AppTheme.textSecondary, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated waveform — bars shift each second, giving the illusion of movement
// ─────────────────────────────────────────────────────────────────────────────
class _Waveform extends StatelessWidget {
  final int tick;
  const _Waveform({required this.tick});

  static const _heights = [
    4.0, 9.0, 14.0, 18.0, 10.0, 6.0, 16.0, 8.0,
    18.0, 5.0, 12.0, 9.0, 16.0, 7.0, 12.0, 5.0,
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(_heights.length, (i) {
          final active = (i + tick) % 3 != 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 2.5,
            height: active ? _heights[i] : _heights[i] * 0.3,
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(
                  alpha: active ? 0.45 + 0.5 * (i / _heights.length) : 0.15),
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        }),
      ),
    );
  }
}
