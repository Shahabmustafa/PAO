/// What happened on a table (or on the channel itself).
enum RealtimeEventType {
  insert,
  update,
  delete,

  /// The channel joined (or re-joined after a dropped connection). Events
  /// that happened while it was down are lost, so listeners re-fetch here.
  subscribed,

  /// The channel could not join, timed out, or closed.
  error,
}

/// One Supabase Realtime event, decoded from a Postgres Changes payload.
class RealtimeEvent<T> {
  const RealtimeEvent({
    required this.type,
    this.id = '',
    this.record,
    this.tag = '',
    this.isReconnect = false,
  });

  final RealtimeEventType type;

  /// Primary key of the affected row (empty for [RealtimeEventType.subscribed]
  /// and [RealtimeEventType.error]).
  final String id;

  /// The new row for insert/update. Null for delete and channel events.
  final T? record;

  /// Which binding produced the event, for channels that listen to the same
  /// table with different filters (e.g. requests `sent` vs `received`).
  final String tag;

  /// For [RealtimeEventType.subscribed]: true when this is a re-join, not
  /// the first one.
  final bool isReconnect;

  bool get isRowChange =>
      type == RealtimeEventType.insert ||
      type == RealtimeEventType.update ||
      type == RealtimeEventType.delete;

  /// Same event with the row converted by [convert] (e.g. JSON -> model).
  RealtimeEvent<R> mapRecord<R>(R Function(T record) convert) {
    final row = record;
    return RealtimeEvent<R>(
      type: type,
      id: id,
      record: row == null ? null : convert(row),
      tag: tag,
      isReconnect: isReconnect,
    );
  }

  @override
  String toString() => 'RealtimeEvent($type, id: $id, tag: $tag)';
}
