import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// A finished voice recording, ready to upload.
typedef VoiceRecording = ({File file, Duration duration});

/// Drives WhatsApp-style hold-to-record voice messages: [start] on press,
/// then either [finish] (release) or [cancel] (slide away / interrupted).
class VoiceRecorderController extends ChangeNotifier {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _timer;
  DateTime? _startedAt;
  Future<bool>? _starting;

  bool isRecording = false;
  Duration elapsed = Duration.zero;

  /// True while the finger has been dragged far enough that releasing now
  /// would discard the recording.
  bool willCancel = false;

  /// Starts recording. Returns false when the microphone permission was
  /// denied (the OS prompt is shown the first time).
  Future<bool> start() {
    if (isRecording) return Future.value(true);
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<bool> _start() async {
    try {
      return await _startRecording();
    } catch (_) {
      // No microphone, or the recorder couldn't open it.
      return false;
    }
  }

  Future<bool> _startRecording() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000),
      path: path,
    );
    _startedAt = DateTime.now();
    elapsed = Duration.zero;
    willCancel = false;
    isRecording = true;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      elapsed = DateTime.now().difference(_startedAt!);
      notifyListeners();
    });
    notifyListeners();
    return true;
  }

  void setWillCancel(bool value) {
    if (willCancel == value) return;
    willCancel = value;
    notifyListeners();
  }

  /// Stops and returns the recording, or null if nothing was being recorded.
  Future<VoiceRecording?> finish() async {
    await _starting;
    if (!isRecording) return null;
    final duration = DateTime.now().difference(_startedAt!);
    _reset();
    final path = await _recorder.stop();
    if (path == null) return null;
    return (file: File(path), duration: duration);
  }

  /// Stops and throws the recording away.
  Future<void> cancel() async {
    await _starting;
    if (!isRecording) return;
    _reset();
    final path = await _recorder.stop();
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  void _reset() {
    _timer?.cancel();
    isRecording = false;
    willCancel = false;
    elapsed = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }
}
