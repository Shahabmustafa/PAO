import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

/// Shrinks photos and videos before they are uploaded. Every method falls
/// back to the original data if compression isn't possible, so a failure
/// here never blocks a post or a message.
class MediaCompressor {
  MediaCompressor._();

  /// Photos are squeezed to about this size.
  static const int targetImageBytes = 50 * 1024;

  /// Compresses JPEG/PNG [bytes] to roughly [targetBytes] by lowering the
  /// quality first and then the resolution.
  static Future<Uint8List> compressImageBytes(
    Uint8List bytes, {
    int targetBytes = targetImageBytes,
  }) async {
    if (kIsWeb) return bytes;
    try {
      var side = 1024;
      var quality = 80;
      var best = bytes;
      for (var attempt = 0; attempt < 10; attempt++) {
        final out = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: side,
          minHeight: side,
          quality: quality,
          format: CompressFormat.jpeg,
        );
        if (out.length < best.length) best = out;
        if (best.length <= targetBytes) break;
        if (quality > 35) {
          quality -= 10;
        } else {
          side = math.max(320, (side * 0.75).round());
        }
      }
      return best;
    } catch (_) {
      return bytes;
    }
  }

  /// File version of [compressImageBytes]; returns a new temp file, or
  /// [file] itself when compression fails.
  static Future<File> compressImageFile(File file) async {
    try {
      final compressed = await compressImageBytes(await file.readAsBytes());
      final out = File(
        '${Directory.systemTemp.path}/img_${DateTime.now().microsecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(compressed, flush: true);
      return out;
    } catch (_) {
      return file;
    }
  }

  /// Re-encodes [file] at a lower resolution and bitrate. Returns the
  /// smaller of the two files.
  static Future<File> compressVideoFile(File file) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      final out = info?.file;
      if (out == null) return file;
      return await out.length() < await file.length() ? out : file;
    } catch (_) {
      return file;
    }
  }
}
