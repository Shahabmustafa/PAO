import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/chat/data/chat_media_cache.dart';

/// The local (Hive) cache. Supabase stays the source of truth; these boxes
/// only let screens paint instantly and keep working offline.
///
/// Every box holds JSON strings, so no type adapters / code generation are
/// needed and a schema change is just a matter of ignoring unknown keys.
///
/// * [products]  - `feed`: the newest page of the public feed
/// * [messages]  - `conv:<otherUserId>`: the latest messages of a chat
/// * [requests]  - `sent` / `received`: first page of each list
/// * [wishlist]  - `items`: the wishlist
/// * [profiles]  - `<userId>`: public profile fields only
/// * [syncQueue] - writes made while offline, replayed later
/// * [meta]      - `uid`: who the cache belongs to
///
/// Categories and provinces are compiled into the app (see
/// `kHomeCategories` / `pakistan_location.dart`), so they need no cache.
///
/// Nothing sensitive is stored here: no tokens, passwords, e-mail or phone.
/// Supabase Auth keeps owning the session.
class LocalCache {
  LocalCache._();

  static Box<String>? products;
  static Box<String>? messages;
  static Box<String>? requests;
  static Box<String>? wishlist;
  static Box<String>? profiles;
  static Box<String>? syncQueue;
  static Box<String>? meta;

  static bool _ready = false;
  static StreamSubscription<AuthState>? _authSubscription;

  static final StreamController<void> _accountChanged =
      StreamController<void>.broadcast();

  /// Fires after the cache was wiped because the signed-in account changed
  /// (or signed out). In-memory stores listen to reset themselves.
  static Stream<void> get accountChanged => _accountChanged.stream;

  static Future<void> init() async {
    await Hive.initFlutter('pao_cache');
    final opened = await Future.wait([
      _open('products'),
      _open('messages'),
      _open('requests'),
      _open('wishlist'),
      _open('profiles'),
      _open('sync_queue'),
      _open('meta'),
    ]);
    products = opened[0];
    messages = opened[1];
    requests = opened[2];
    wishlist = opened[3];
    profiles = opened[4];
    syncQueue = opened[5];
    meta = opened[6];
    _ready = true;

    // A cache left behind by another account must never be shown.
    await _adoptUser(_currentUid(), notify: false);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (state) => _adoptUser(state.session?.user.id, notify: true),
    );
  }

  static Future<Box<String>> _open(String name) async {
    try {
      return await Hive.openBox<String>(name);
    } catch (e) {
      // A corrupt box is only a cache: start it over.
      debugPrint('[LocalCache] resetting $name: $e');
      await Hive.deleteBoxFromDisk(name);
      return Hive.openBox<String>(name);
    }
  }

  static String? _currentUid() => Supabase.instance.client.auth.currentUser?.id;

  static Future<void> _adoptUser(String? uid, {required bool notify}) async {
    if (!_ready) return;
    final owner = meta?.get('uid');
    if (uid == owner) return;
    if (owner != null) {
      // Signed out, or a different account signed in: nothing cached for
      // the previous one may survive.
      await clearAll();
      if (notify) _accountChanged.add(null);
    }
    // (No owner yet means the boxes hold no user data, so a first sign-in
    // just claims them and nothing already loaded is disturbed.)
    if (uid != null) await meta?.put('uid', uid);
  }

  /// Whether [name] was synced from Supabase less than [maxAge] ago. Screens
  /// use it to paint from the cache and skip a network reload; a pull to
  /// refresh always reloads. False when the cache isn't open.
  static bool isFresh(String name, Duration maxAge) {
    final at = meta?.get('synced:$name');
    if (at == null) return false;
    final ms = int.tryParse(at);
    if (ms == null) return false;
    return DateTime.now().millisecondsSinceEpoch - ms < maxAge.inMilliseconds;
  }

  static void markSynced(String name) {
    final box = meta;
    if (box == null) return;
    unawaited(
      box
          .put('synced:$name', '${DateTime.now().millisecondsSinceEpoch}')
          .catchError((_) {}),
    );
  }

  /// Wipes every box. Used on logout and when the account changes.
  static Future<void> clearAll() async {
    if (!_ready) return;
    await ChatMediaCache.clear();
    await Future.wait([
      for (final box in [
        products,
        messages,
        requests,
        wishlist,
        profiles,
        syncQueue,
        meta,
      ])
        if (box != null) box.clear(),
    ]);
  }

  static Future<void> dispose() async => _authSubscription?.cancel();

  // JSON helpers. A missing/corrupt entry reads as null, never throws.

  // A null box means the cache isn't open (e.g. in unit tests): reads come
  // back empty and writes are dropped, so callers never need to check.

  static Object? read(Box<String>? box, String key) {
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> readList(Box<String>? box, String key) {
    final value = read(box, key);
    if (value is! List) return [];
    return [
      for (final item in value)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  static Map<String, dynamic>? readMap(Box<String>? box, String key) {
    final value = read(box, key);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static void write(Box<String>? box, String key, Object value) {
    if (box == null) return;
    // Fire and forget: the in-memory copy is already up to date.
    unawaited(box.put(key, jsonEncode(value)).catchError((_) {}));
  }
}
