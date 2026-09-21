import 'package:flutter/foundation.dart';

/// Debug-only log line for Supabase Realtime. Filter the console on
/// `[Realtime]` to watch subscriptions and events arrive.
void realtimeLog(String message) {
  if (kDebugMode) debugPrint('[Realtime] $message');
}
