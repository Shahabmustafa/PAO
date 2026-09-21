import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'realtime_event.dart';
import 'realtime_log.dart';

/// One `postgres_changes` listener on a channel: an [event] on the table,
/// optionally narrowed by [filter], reported with [tag].
class RealtimeBinding {
  const RealtimeBinding({required this.event, this.filter, this.tag = ''});

  final PostgresChangeEvent event;
  final PostgresChangeFilter? filter;
  final String tag;
}

int _channelSeq = 0;

/// Exposes a Supabase Realtime channel on `public.[table]` as a stream of
/// [RealtimeEvent]s.
///
/// The channel is created when the stream gets its listener and removed from
/// the socket when that subscription is cancelled, so cancelling the
/// subscription is all a store or provider has to do to clean up. It is a
/// single-subscription stream: call this again for another listener.
///
/// Besides row changes it emits [RealtimeEventType.subscribed] each time the
/// channel joins (`isReconnect` set from the second time on) and
/// [RealtimeEventType.error] when it can't.
///
/// Realtime does not apply a filter to DELETE events (the old row only has
/// its primary key), so delete bindings should be added without a filter and
/// matched to local state by id.
Stream<RealtimeEvent<Map<String, dynamic>>> watchTable(
  SupabaseClient client, {
  required String channelName,
  required String table,
  required List<RealtimeBinding> bindings,
}) {
  late final StreamController<RealtimeEvent<Map<String, dynamic>>> controller;
  RealtimeChannel? channel;
  var joinedBefore = false;
  // Unique per call: a channel with the same name that is still being torn
  // down would otherwise be picked up by the new one.
  final name = '$channelName#${++_channelSeq}';

  void emit(RealtimeEvent<Map<String, dynamic>> event) {
    if (!controller.isClosed) controller.add(event);
  }

  controller = StreamController<RealtimeEvent<Map<String, dynamic>>>(
    onListen: () {
      realtimeLog('[$name] subscribing to public.$table');
      final created = client.channel(name);
      for (final binding in bindings) {
        created.onPostgresChanges(
          event: binding.event,
          schema: 'public',
          table: table,
          filter: binding.filter,
          callback: (payload) {
            final event = _decode(payload, binding.tag);
            if (event == null) {
              realtimeLog('[$name] ignored ${payload.eventType.name}: no id');
              return;
            }
            realtimeLog(
              '[$name] ${event.type.name.toUpperCase()} public.$table '
              'id=${event.id}'
              '${binding.tag.isEmpty ? '' : ' tag=${binding.tag}'}',
            );
            emit(event);
          },
        );
      }
      created.subscribe((status, [error]) {
        realtimeLog(
          '[$name] status=${status.name}${error == null ? '' : ' error=$error'}',
        );
        switch (status) {
          case RealtimeSubscribeStatus.subscribed:
            emit(
              RealtimeEvent(
                type: RealtimeEventType.subscribed,
                isReconnect: joinedBefore,
              ),
            );
            joinedBefore = true;
          case RealtimeSubscribeStatus.channelError:
          case RealtimeSubscribeStatus.timedOut:
          case RealtimeSubscribeStatus.closed:
            emit(const RealtimeEvent(type: RealtimeEventType.error));
        }
      });
      channel = created;
    },
    onCancel: () async {
      realtimeLog('[$name] unsubscribing');
      final created = channel;
      channel = null;
      if (created != null) {
        try {
          await client.removeChannel(created);
        } catch (e) {
          realtimeLog('[$name] removeChannel failed: $e');
        }
      }
    },
  );
  return controller.stream;
}

RealtimeEvent<Map<String, dynamic>>? _decode(
  PostgresChangePayload payload,
  String tag,
) {
  switch (payload.eventType) {
    case PostgresChangeEvent.insert:
    case PostgresChangeEvent.update:
      final id = payload.newRecord['id'];
      if (id is! String) return null;
      return RealtimeEvent(
        type: payload.eventType == PostgresChangeEvent.insert
            ? RealtimeEventType.insert
            : RealtimeEventType.update,
        id: id,
        record: payload.newRecord,
        tag: tag,
      );
    case PostgresChangeEvent.delete:
      final id = payload.oldRecord['id'];
      if (id is! String) return null;
      return RealtimeEvent(type: RealtimeEventType.delete, id: id, tag: tag);
    case PostgresChangeEvent.all:
      return null;
  }
}
