import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/realtime/realtime_event.dart';
import '../../../../core/realtime/realtime_table_stream.dart';

/// Talks directly to Supabase (the `messages` table), including the
/// realtime channel that powers live chat.
///
/// A conversation is identified by the pair of participants
/// (`sender_id`/`recipient_id`), not by a single request -- two users share
/// one chat no matter how many products/requests pass between them.
class ChatRemoteDataSource {
  ChatRemoteDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// One page of the conversation, newest first. [before] is the keyset
  /// cursor (the `created_at` of the oldest message already held); leave it
  /// null for the latest page. Keyset instead of OFFSET keeps every page
  /// equally cheap however long the chat is, and isn't thrown off by new
  /// messages arriving meanwhile.
  Future<List<Map<String, dynamic>>> fetchMessagesPage({
    required String currentUserId,
    required String otherUserId,
    DateTime? before,
    required int limit,
  }) async {
    var query = _client
        .from('messages')
        .select()
        .or(_pairFilter(currentUserId, otherUserId));
    if (before != null) {
      query = query.lt('created_at', before.toUtc().toIso8601String());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// A PostgREST `.or()` expression matching a message in either direction
  /// between [a] and [b].
  String _pairFilter(String a, String b) =>
      'and(sender_id.eq.$a,recipient_id.eq.$b),and(sender_id.eq.$b,recipient_id.eq.$a)';

  /// Live events for the chat between [currentUserId] and [otherUserId].
  ///
  /// Realtime accepts one column filter per binding, so the pair can't be
  /// matched exactly server-side; the bindings are narrowed as far as
  /// possible instead:
  ///  * INSERT / UPDATE from the other user (RLS already limits these to
  ///    rows the current user may see, i.e. ones addressed to them),
  ///  * UPDATE of the current user's own messages (read ticks, reactions,
  ///    edits by another device). Their own INSERTs are applied locally by
  ///    the optimistic send, so no INSERT binding is needed.
  /// The listener still checks each event belongs to this pair. DELETE
  /// events can't be filtered and are matched by id.
  Stream<RealtimeEvent<Map<String, dynamic>>> watchConversation({
    required String currentUserId,
    required String otherUserId,
  }) {
    PostgresChangeFilter sender(String id) => PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'sender_id',
      value: id,
    );
    return watchTable(
      _client,
      channelName: 'chat:$currentUserId:$otherUserId',
      table: 'messages',
      bindings: [
        RealtimeBinding(
          event: PostgresChangeEvent.insert,
          filter: sender(otherUserId),
        ),
        RealtimeBinding(
          event: PostgresChangeEvent.update,
          filter: sender(otherUserId),
        ),
        RealtimeBinding(
          event: PostgresChangeEvent.update,
          filter: sender(currentUserId),
        ),
        const RealtimeBinding(event: PostgresChangeEvent.delete),
      ],
    );
  }

  /// Inserts a message. [id] is generated on the device so the optimistic
  /// copy and the server row share one id (that is what de-duplicates the
  /// Realtime echo).
  Future<Map<String, dynamic>> sendMessage({
    String? id,
    String? requestId,
    required String senderId,
    required String recipientId,
    required String body,
    String? replyToId,
    String? mediaType,
    String? mediaPath,
    int? mediaDurationMs,
  }) {
    return _client
        .from('messages')
        .insert({
          'id': ?id,
          'reply_to_id': replyToId,
          'request_id': requestId,
          'sender_id': senderId,
          'recipient_id': recipientId,
          'body': body,
          'media_type': mediaType,
          'media_path': mediaPath,
          'media_duration_ms': mediaDurationMs,
        })
        .select()
        .single();
  }

  static const _mediaBucket = 'chat_media';

  /// Uploads [file] to the private chat-media bucket under the sender's own
  /// folder (see supabase/messages_add_media.sql) and returns its path.
  Future<String> uploadMedia({
    required String userId,
    required File file,
    required String extension,
    required String contentType,
  }) async {
    final path = '$userId/${DateTime.now().microsecondsSinceEpoch}.$extension';
    await _client.storage
        .from(_mediaBucket)
        .upload(path, file, fileOptions: FileOptions(contentType: contentType));
    return path;
  }

  /// A short-lived URL for reading a private media file.
  Future<String> mediaUrl(String path) =>
      _client.storage.from(_mediaBucket).createSignedUrl(path, 60 * 60 * 6);

  /// Best-effort cleanup of a file whose message failed to send.
  Future<void> removeMedia(String path) async {
    await _client.storage.from(_mediaBucket).remove([path]);
  }

  Future<void> deleteMessage(String messageId) {
    return _client.from('messages').delete().eq('id', messageId);
  }

  /// Sets the current user's reaction on [messageId], or removes it when
  /// [emoji] is null.
  Future<void> reactToMessage(String messageId, String? emoji) {
    return _client.rpc(
      'react_to_message',
      params: {'p_message_id': messageId, 'p_emoji': emoji},
    );
  }

  /// Hides [messageId] from the current user's view only (see
  /// supabase/messages_add_deleted_for.sql).
  Future<void> deleteMessageForMe(String messageId) {
    return _client.rpc(
      'delete_message_for_me',
      params: {'p_message_id': messageId},
    );
  }

  /// Marks every unread message [readerId] received from [otherUserId] as
  /// seen. The sender's own realtime subscription picks up the resulting
  /// UPDATE, so their ticks flip to "read" live.
  Future<void> markMessagesRead({
    required String readerId,
    required String otherUserId,
  }) {
    return _client
        .from('messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', readerId)
        .eq('sender_id', otherUserId)
        .isFilter('read_at', null);
  }

  /// Edits one of the current user's own messages. `edited_at` is stamped
  /// server-side by `guard_message_update` (see
  /// supabase/messages_add_read_edited.sql), not sent from here.
  Future<Map<String, dynamic>> editMessage({
    required String messageId,
    required String body,
  }) {
    return _client
        .from('messages')
        .update({'body': body})
        .eq('id', messageId)
        .select()
        .single();
  }

  /// Every unread message [userId] has received, across every conversation
  /// -- used to badge each request tile with how many messages that other
  /// participant has sent.
  Future<List<Map<String, dynamic>>> fetchUnread(String userId) async {
    final rows = await _client
        .from('messages')
        .select()
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  /// Live changes to [userId]'s incoming messages -- powers the unread
  /// badges without re-fetching on every event.
  Stream<RealtimeEvent<Map<String, dynamic>>> watchUnread(String userId) {
    final toMe = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'recipient_id',
      value: userId,
    );
    return watchTable(
      _client,
      channelName: 'messages:unread:$userId',
      table: 'messages',
      bindings: [
        RealtimeBinding(event: PostgresChangeEvent.insert, filter: toMe),
        RealtimeBinding(event: PostgresChangeEvent.update, filter: toMe),
        const RealtimeBinding(event: PostgresChangeEvent.delete),
      ],
    );
  }
}
