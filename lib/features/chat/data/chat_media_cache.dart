import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// On-disk copy of chat photos / videos / voice messages, so they open
/// instantly and offline after the first view (or right after sending).
///
/// Hive boxes only hold JSON strings, so the bytes live as plain files in
/// the app support directory, named after the message's storage path. The
/// message JSON in `LocalCache.messages` already carries that path, which
/// makes the path the index. [LocalCache] calls [clear] when the account
/// changes or signs out.
class ChatMediaCache {
  ChatMediaCache._();

  static Directory? _dir;
  static final _inFlight = <String, Future<File>>{};

  static Future<Directory> _directory() async {
    final existing = _dir;
    if (existing != null && existing.existsSync()) return existing;
    final base = await getApplicationSupportDirectory();
    return _dir = await Directory(
      '${base.path}/chat_media',
    ).create(recursive: true);
  }

  static String _name(String path) => path.replaceAll(RegExp(r'[^\w.\-]'), '_');

  static Future<File> _fileFor(String path) async =>
      File('${(await _directory()).path}/${_name(path)}');

  /// The cached file for [path], or null when it isn't stored yet.
  static Future<File?> get(String path) async {
    try {
      final file = await _fileFor(path);
      if (file.existsSync() && file.lengthSync() > 0) return file;
    } catch (e) {
      debugPrint('[ChatMediaCache] get failed: $e');
    }
    return null;
  }

  /// Keeps a copy of a file we just uploaded, so the sender never has to
  /// download their own media.
  static Future<void> put(String path, File source) async {
    try {
      final target = await _fileFor(path);
      await source.copy(target.path);
    } catch (e) {
      debugPrint('[ChatMediaCache] put failed: $e');
    }
  }

  /// Drops the cached copy of [path] (its message was cleared).
  static Future<void> remove(String path) async {
    try {
      final file = await _fileFor(path);
      if (file.existsSync()) await file.delete();
    } catch (e) {
      debugPrint('[ChatMediaCache] remove failed: $e');
    }
  }

  /// The file for [path]: from disk when cached, otherwise downloaded from
  /// [resolveUrl] and stored. Concurrent calls share one download.
  static Future<File> load(
    String path,
    Future<String> Function() resolveUrl,
  ) async {
    final cached = await get(path);
    if (cached != null) return cached;
    return _inFlight.putIfAbsent(path, () async {
      try {
        return await _download(path, await resolveUrl());
      } finally {
        _inFlight.remove(path);
      }
    });
  }

  static Future<File> _download(String path, String url) async {
    final target = await _fileFor(path);
    final partial = File('${target.path}.part');
    final client = http.Client();
    try {
      final response = await client.send(http.Request('GET', Uri.parse(url)));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final sink = partial.openWrite();
      try {
        await response.stream.pipe(sink);
      } catch (_) {
        await partial.delete().catchError((_) => partial);
        rethrow;
      }
      // Only a complete download gets the final name.
      return await partial.rename(target.path);
    } finally {
      client.close();
    }
  }

  static Future<void> clear() async {
    try {
      _inFlight.clear();
      final dir = await _directory();
      if (dir.existsSync()) await dir.delete(recursive: true);
      _dir = null;
    } catch (e) {
      debugPrint('[ChatMediaCache] clear failed: $e');
    }
  }
}
