import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../data/model/message_model.dart';
import '../../../../core/l10n/l10n.dart';
import '../provider/chat_provider.dart';

String formatMediaDuration(Duration d) {
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '${d.inMinutes}:$seconds';
}

/// The photo / video / voice content of a chat bubble.
///
/// Photos and videos fill the bubble edge to edge with the time / ticks
/// ([overlayMeta]) laid over their bottom corner; voice messages show the
/// time / ticks ([meta]) under the waveform.
class ChatMediaContent extends StatelessWidget {
  const ChatMediaContent({
    super.key,
    required this.message,
    required this.foreground,
    required this.accent,
    required this.meta,
    required this.overlayMeta,
  });

  final MessageModel message;

  /// Text / icon colour that reads on the bubble.
  final Color foreground;

  /// Colour of the played part of a voice message's waveform.
  final Color accent;

  final Widget meta;
  final Widget overlayMeta;

  @override
  Widget build(BuildContext context) {
    final type = message.mediaType!;
    if (type == MessageMediaType.audio) {
      return _AudioContent(
        message: message,
        foreground: foreground,
        accent: accent,
        meta: meta,
      );
    }
    return Stack(
      children: [
        type == MessageMediaType.image
            ? _ImageContent(message: message)
            : _VideoContent(message: message),
        PositionedDirectional(
          end: 6,
          bottom: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: overlayMeta,
          ),
        ),
      ],
    );
  }
}

/// Resolves a message's media to a local file (disk cache first, downloaded
/// once otherwise), with a spinner while loading and tap-to-retry on failure.
class _MediaFile extends StatefulWidget {
  const _MediaFile({
    required this.path,
    required this.builder,
    required this.placeholderSize,
  });

  final String path;
  final Widget Function(BuildContext context, File file) builder;
  final Size placeholderSize;

  @override
  State<_MediaFile> createState() => _MediaFileState();
}

class _MediaFileState extends State<_MediaFile> {
  late Future<File> _file = _load();

  Future<File> _load() => context.read<ChatProvider>().mediaFile(widget.path);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _file,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) return widget.builder(context, file);
        return GestureDetector(
          onTap: snapshot.hasError
              ? () => setState(() => _file = _load())
              : null,
          child: _MediaPlaceholder(
            size: widget.placeholderSize,
            child: snapshot.hasError
                ? const Icon(Icons.refresh, color: Colors.white70)
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  const _MediaPlaceholder({required this.size, this.child});

  final Size size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: const Color(0xFF1F2C34),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

const _mediaWidth = 240.0;

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    final path = message.mediaPath!;
    const size = Size(_mediaWidth, _mediaWidth);
    return _MediaFile(
      path: path,
      placeholderSize: size,
      builder: (context, file) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => ImageViewerPage(file: file)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _mediaWidth,
              maxHeight: 320,
            ),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _MediaPlaceholder(
                size: size,
                child: Icon(Icons.broken_image_outlined, color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.message});

  final MessageModel message;

  @override
  Widget build(BuildContext context) {
    const size = Size(_mediaWidth, 170);
    final durationMs = message.mediaDurationMs;
    return _MediaFile(
      path: message.mediaPath!,
      placeholderSize: size,
      builder: (context, file) => GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => VideoPlayerPage(file: file)),
        ),
        child: _MediaPlaceholder(
          size: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              if (durationMs != null)
                PositionedDirectional(
                  start: 8,
                  bottom: 6,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam_rounded,
                        size: 16,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formatMediaDuration(Duration(milliseconds: durationMs)),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Voice message: play / pause, a seekable waveform, the duration and the
/// time / ticks.
class _AudioContent extends StatelessWidget {
  const _AudioContent({
    required this.message,
    required this.foreground,
    required this.accent,
    required this.meta,
  });

  final MessageModel message;
  final Color foreground;
  final Color accent;
  final Widget meta;

  @override
  Widget build(BuildContext context) {
    return _MediaFile(
      path: message.mediaPath!,
      placeholderSize: const Size(_audioWidth, 52),
      builder: (context, file) => _AudioPlayer(
        file: file,
        seed: message.mediaPath!,
        knownDuration: Duration(milliseconds: message.mediaDurationMs ?? 0),
        foreground: foreground,
        accent: accent,
        meta: meta,
      ),
    );
  }
}

const _audioWidth = 240.0;

class _AudioPlayer extends StatefulWidget {
  const _AudioPlayer({
    required this.file,
    required this.seed,
    required this.knownDuration,
    required this.foreground,
    required this.accent,
    required this.meta,
  });

  final File file;
  final String seed;
  final Duration knownDuration;
  final Color foreground;
  final Color accent;
  final Widget meta;

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer>
    with AutomaticKeepAliveClientMixin {
  /// A playing message must survive being scrolled out of the list, or its
  /// player would be disposed and the audio would stop.
  @override
  bool get wantKeepAlive => _playing || _loading;

  /// Only one voice message plays at a time.
  static _AudioPlayerState? _active;

  AudioPlayer? _player;
  final _subscriptions = <StreamSubscription<Object?>>[];
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  late Duration _total = widget.knownDuration;
  late final List<double> _bars = _waveformFor(widget.seed);

  /// A stable, voice-like set of bar heights (0.15 - 1.0) for [seed]; the
  /// real amplitudes aren't stored, so this is decorative.
  static List<double> _waveformFor(String seed) {
    final random = math.Random(seed.hashCode);
    var level = 0.5;
    return [
      for (var i = 0; i < 36; i++)
        level = (level + (random.nextDouble() - 0.5) * 0.9).clamp(0.15, 1.0),
    ];
  }

  AudioPlayer _ensurePlayer() {
    final existing = _player;
    if (existing != null) return existing;
    final player = AudioPlayer();
    _subscriptions.addAll([
      player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
      player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _total = d);
      }),
      player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() => _playing = state == PlayerState.playing);
        updateKeepAlive();
      }),
      player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _position = Duration.zero;
          });
          updateKeepAlive();
        }
      }),
    ]);
    return _player = player;
  }

  Future<void> _toggle() async {
    final player = _ensurePlayer();
    if (_playing) {
      await player.pause();
      return;
    }
    if (_active != this) await _active?._pause();
    _active = this;
    if (player.state == PlayerState.paused) {
      await player.resume();
      return;
    }
    setState(() => _loading = true);
    updateKeepAlive();
    try {
      await player.play(DeviceFileSource(widget.file.path));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        updateKeepAlive();
      }
    }
  }

  Future<void> _pause() async {
    await _player?.pause();
  }

  Duration _at(double fraction) =>
      Duration(milliseconds: (fraction * _total.inMilliseconds).round());

  @override
  void dispose() {
    if (_active == this) _active = null;
    for (final s in _subscriptions) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final totalMs = _total.inMilliseconds;
    final progress = totalMs > 0
        ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final canSeek = totalMs > 0;
    final started = _playing || _position > Duration.zero;
    return SizedBox(
      width: _audioWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkResponse(
            onTap: _toggle,
            radius: 24,
            child: SizedBox(
              width: 40,
              height: 40,
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(9),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: widget.foreground,
                      ),
                    )
                  : Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: widget.foreground,
                      size: 38,
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                // Waveforms read left to right in every language.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: _Waveform(
                    bars: _bars,
                    progress: progress,
                    playedColor: widget.accent,
                    idleColor: widget.foreground.withValues(alpha: 0.3),
                    onSeek: canSeek
                        ? (fraction) =>
                              setState(() => _position = _at(fraction))
                        : null,
                    onSeekEnd: canSeek
                        ? (fraction) => _ensurePlayer().seek(_at(fraction))
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatMediaDuration(started ? _position : _total),
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.foreground.withValues(alpha: 0.65),
                      ),
                    ),
                    const Spacer(),
                    widget.meta,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bars that fill in as playback progresses; tap or drag to seek.
class _Waveform extends StatelessWidget {
  const _Waveform({
    required this.bars,
    required this.progress,
    required this.playedColor,
    required this.idleColor,
    this.onSeek,
    this.onSeekEnd,
  });

  final List<double> bars;
  final double progress;
  final Color playedColor;
  final Color idleColor;
  final ValueChanged<double>? onSeek;
  final ValueChanged<double>? onSeekEnd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        double fraction(double dx) => (dx / width).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onSeek?.call(fraction(d.localPosition.dx)),
          onTapUp: (d) => onSeekEnd?.call(fraction(d.localPosition.dx)),
          onHorizontalDragUpdate: (d) =>
              onSeek?.call(fraction(d.localPosition.dx)),
          onHorizontalDragEnd: (_) => onSeekEnd?.call(progress),
          child: CustomPaint(
            size: Size(width, 28),
            painter: _WaveformPainter(bars, progress, playedColor, idleColor),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.bars, this.progress, this.played, this.idle);

  final List<double> bars;
  final double progress;
  final Color played;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / bars.length;
    final paint = Paint()
      ..strokeWidth = math.max(2, slot * 0.55)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < bars.length; i++) {
      final height = bars[i] * size.height;
      final x = slot * i + slot / 2;
      paint.color = (i + 0.5) / bars.length <= progress ? played : idle;
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
    // A knob at the current position, like WhatsApp's.
    if (progress > 0) {
      canvas.drawCircle(
        Offset(size.width * progress, size.height / 2),
        5,
        Paint()..color = played,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.played != played ||
      old.idle != idle ||
      old.bars != bars;
}

/// Full-screen, pinch-to-zoom photo.
class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SizedBox.expand(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white70),
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen video with tap-to-pause and a scrubbable progress bar.
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.file});

  final File file;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            if (value.hasError) {
              return const Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 40,
              );
            }
            if (!value.isInitialized) return const CircularProgressIndicator();
            return GestureDetector(
              onTap: _toggle,
              child: AspectRatio(
                aspectRatio: value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (!value.isPlaying)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// What to show for [message] where only a short text preview fits (a
/// reply quote): its text, or "Photo" / "Video" / "Voice message".
String messagePreview(BuildContext context, MessageModel message) {
  if (!message.hasMedia) return message.body;
  final l10n = context.l10n;
  return switch (message.mediaType!) {
    MessageMediaType.image => '📷 ${l10n.photoLabel}',
    MessageMediaType.video => '🎥 ${l10n.videoLabel}',
    MessageMediaType.audio => '🎤 ${l10n.voiceMessageLabel}',
  };
}
