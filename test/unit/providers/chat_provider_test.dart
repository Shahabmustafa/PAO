import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/chat/presentation/provider/chat_provider.dart';
import 'package:pao/features/feedback/data/model/feedback_model.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/requests/data/request_store.dart';
import 'package:pao/features/chat/data/model/message_model.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeChatRepository chat;
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;
  late FakeFeedbackRepository feedback;

  ChatProvider build({RequestModel? request, String otherUserId = 'owner-1'}) {
    final provider = ChatProvider(
      request: request ?? makeRequest(),
      otherUserId: otherUserId,
      repository: chat,
      authRepository: auth,
      profileRepository: profiles,
      feedbackRepository: feedback,
    );
    addTearDown(provider.dispose);
    return provider;
  }

  setUp(() {
    chat = FakeChatRepository();
    // requester-1 is the current user; owner-1 owns the item.
    auth = FakeAuthRepository(user: const UserModel(id: 'requester-1'));
    profiles = FakeProfileRepository()..publicProfile = kOtherProfile;
    feedback = FakeFeedbackRepository();
  });

  group('roles', () {
    test('requester', () {
      final provider = build();

      expect(provider.isRequester, isTrue);
      expect(provider.isOwner, isFalse);
      expect(provider.currentUserId, 'requester-1');
    });

    test('owner', () {
      auth.user = const UserModel(id: 'owner-1');
      final provider = build(otherUserId: 'requester-1');

      expect(provider.isOwner, isTrue);
      expect(provider.isRequester, isFalse);
    });
  });

  group('messages', () {
    // A message with its own timestamp, so ordering is deterministic.
    MessageModel msg(
      String id, {
      int minute = 0,
      String senderId = 'owner-1',
      String recipientId = 'requester-1',
    }) => MessageModel(
      id: id,
      requestId: 'req-1',
      senderId: senderId,
      recipientId: recipientId,
      body: 'body $id',
      createdAt: kCreatedAt.add(Duration(minutes: minute)),
    );

    test(
      'starts loading, then shows the history once the channel joins',
      () async {
        chat.history = [msg('a'), msg('b', minute: 1)];
        final provider = build();
        expect(provider.isLoading, isTrue);

        chat.controller.add(subscribedEvent());
        await pumpEventQueue();

        expect(provider.isLoading, isFalse);
        expect(provider.messages.map((m) => m.id), ['a', 'b']);
      },
    );

    test('a new message arrives live, in order, without a refetch', () async {
      chat.history = [msg('a')];
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();
      var notified = 0;
      provider.addListener(() => notified++);
      final fetchesBefore = chat.fetchCalls;

      chat.controller.add(insertEvent('b', msg('b', minute: 1)));
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.id), ['a', 'b']);
      expect(notified, 1);
      expect(chat.fetchCalls, fetchesBefore, reason: 'no refetch per event');
    });

    test('the same message delivered twice appears once', () async {
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      chat.controller.add(insertEvent('a', msg('a')));
      chat.controller.add(insertEvent('a', msg('a')));
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.id), ['a']);
    });

    test('a live message that beat the history fetch is kept once', () async {
      chat.history = [msg('a'), msg('b', minute: 1)];
      final provider = build();

      // 'b' arrives live before the fetch response is merged in.
      chat.controller.add(insertEvent('b', msg('b', minute: 1)));
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.id), ['a', 'b']);
    });

    test('a live message newer than the fetched history is kept', () async {
      chat.history = [msg('a')];
      final provider = build();

      chat.controller.add(insertEvent('b', msg('b', minute: 1)));
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.id), ['a', 'b']);
    });

    test('a live UPDATE replaces the message in place', () async {
      chat.history = [msg('a'), msg('b', minute: 1)];
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      chat.controller.add(
        updateEvent(
          'a',
          MessageModel(
            id: 'a',
            requestId: 'req-1',
            senderId: 'owner-1',
            recipientId: 'requester-1',
            body: 'edited',
            createdAt: kCreatedAt,
          ),
        ),
      );
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.body), ['edited', 'body b']);
    });

    test(
      'a live DELETE removes the message, and ignores other chats',
      () async {
        chat.history = [msg('a'), msg('b', minute: 1)];
        final provider = build();
        chat.controller.add(subscribedEvent());
        await pumpEventQueue();
        var notified = 0;
        provider.addListener(() => notified++);

        chat.controller.add(deleteEvent('not-in-this-chat'));
        await pumpEventQueue();
        expect(provider.messages, hasLength(2));
        expect(notified, 0, reason: 'unknown ids are ignored');

        chat.controller.add(deleteEvent('a'));
        await pumpEventQueue();
        expect(provider.messages.map((m) => m.id), ['b']);
      },
    );

    test('a message between two other users is ignored, even with the same '
        'request id', () async {
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      chat.controller.add(
        insertEvent(
          'x',
          MessageModel(
            id: 'x',
            requestId: 'req-1',
            senderId: 'someone-else',
            recipientId: 'another-person',
            body: 'wrong chat',
            createdAt: kCreatedAt,
          ),
        ),
      );
      await pumpEventQueue();

      expect(provider.messages, isEmpty);
    });

    test('re-joining after a dropped connection reloads the history', () async {
      chat.history = [msg('a')];
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      // While disconnected, 'a' was deleted and 'b' arrived.
      chat.history = [msg('b', minute: 1)];
      chat.controller.add(subscribedEvent(isReconnect: true));
      await pumpEventQueue();

      expect(provider.messages.map((m) => m.id), [
        'b',
      ], reason: 'a was deleted while offline');
      expect(chat.fetchCalls, 2);
    });

    test('if realtime cannot connect the history still loads', () async {
      chat.history = [msg('a')];
      final provider = build();

      chat.controller.add(errorEvent());
      await pumpEventQueue();

      expect(provider.isLoading, isFalse);
      expect(provider.messages.map((m) => m.id), ['a']);
    });

    test('a failed history load shows a message and stops loading', () async {
      chat.fetchError = Exception('offline');
      final provider = build();

      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      expect(provider.errorMessage, 'Failed to load messages.');
      expect(provider.isLoading, isFalse);
    });

    test('a stream error shows a message and stops loading', () async {
      final provider = build();

      chat.controller.addError(Exception('realtime dropped'));
      await pumpEventQueue();

      expect(provider.errorMessage, 'Failed to load messages.');
      expect(provider.isLoading, isFalse);
    });

    test('dispose cancels the subscription', () async {
      final provider = ChatProvider(
        request: makeRequest(),
        otherUserId: 'owner-1',
        repository: chat,
        authRepository: auth,
        profileRepository: profiles,
        feedbackRepository: feedback,
      );
      expect(chat.controller.hasListener, isTrue);
      // Let the async profile lookup finish first: notifying after dispose
      // would (in debug builds) throw "used after being disposed".
      await pumpEventQueue();

      provider.dispose();

      expect(chat.controller.hasListener, isFalse);
    });
  });

  group('live request status', () {
    tearDown(RequestStore.reset);

    test('follows the request when the owner accepts it', () async {
      final provider = build(request: makeRequest(status: 'pending'));
      await pumpEventQueue();
      var notified = 0;
      provider.addListener(() => notified++);

      RequestStore.sent.value = [makeRequest(status: 'accepted')];

      expect(provider.request.status, 'accepted');
      expect(notified, 1);
    });

    test('ignores other requests', () async {
      final provider = build(request: makeRequest(status: 'pending'));
      await pumpEventQueue();

      RequestStore.sent.value = [makeRequest(id: 'other', status: 'accepted')];

      expect(provider.request.status, 'pending');
    });

    test('stops listening once disposed', () async {
      final provider = ChatProvider(
        request: makeRequest(),
        otherUserId: 'owner-1',
        repository: chat,
        authRepository: auth,
        profileRepository: profiles,
        feedbackRepository: feedback,
      );
      await pumpEventQueue();
      provider.dispose();

      // Would throw "used after being disposed" if it were still listening.
      RequestStore.received.value = [makeRequest(status: 'accepted')];
    });
  });

  group('other user profile', () {
    test('loads the other participant', () async {
      final provider = build();
      await pumpEventQueue();

      expect(provider.isLoadingProfile, isFalse);
      expect(provider.otherProfile!.fullName, 'Ayesha Khan');
    });

    test('falls back gracefully when the lookup fails', () async {
      profiles.fetchError = Exception('offline');

      final provider = build();
      await pumpEventQueue();

      expect(provider.isLoadingProfile, isFalse);
      expect(provider.otherProfile, isNull);
    });
  });

  group('sendMessage', () {
    test('sends the trimmed text as the current user', () async {
      final provider = build();

      await provider.sendMessage('  Assalam o Alaikum  ');

      final sent = chat.sent.single;
      expect(sent.body, 'Assalam o Alaikum');
      expect(sent.senderId, 'requester-1');
      expect(sent.requestId, 'req-1');
    });

    test(
      'the sent message shows at once and its realtime echo is not doubled',
      () async {
        final provider = build();

        await provider.sendMessage('hello');
        final id = provider.messages.single.id;
        expect(provider.messages.single.status, MessageStatus.sent);

        // Realtime then delivers the same row back to the sender.
        chat.controller.add(
          insertEvent(
            id,
            makeMessage(
              id: id,
              senderId: 'requester-1',
              recipientId: 'owner-1',
              body: 'hello',
            ),
          ),
        );
        await pumpEventQueue();

        expect(provider.messages.map((m) => m.id), [id]);
      },
    );

    test('ignores empty and whitespace-only text', () async {
      final provider = build();

      await provider.sendMessage('');
      await provider.sendMessage('   \n ');

      expect(chat.sent, isEmpty);
    });

    test('does nothing when signed out', () async {
      auth.user = null;
      final provider = build();

      await provider.sendMessage('hello');

      expect(chat.sent, isEmpty);
    });

    test(
      'a failure keeps the message, marked failed, and can be retried',
      () async {
        chat.sendError = Exception('offline');
        final provider = build();

        await provider.sendMessage('hello');

        expect(provider.errorMessage, 'Failed to send message.');
        expect(provider.messages.single.status, MessageStatus.failed);

        chat.sendError = null;
        await provider.retry(provider.messages.single);

        expect(provider.messages, hasLength(1));
        expect(provider.messages.single.status, MessageStatus.sent);
        // The retry reuses the same id, so the server can't store it twice.
        expect(chat.sent, hasLength(1));
      },
    );

    test('the message is shown as sending while it is in flight', () async {
      final provider = build();
      final states = <MessageStatus>[];
      provider.addListener(() {
        if (provider.messages.isNotEmpty) {
          states.add(provider.messages.single.status);
        }
      });

      await provider.sendMessage('hello');

      expect(states.first, MessageStatus.sending);
      expect(states.last, MessageStatus.sent);
    });
  });

  group('pagination', () {
    test('loads the latest page, then older ones on demand', () async {
      chat.history = [
        for (var i = 0; i < 45; i++)
          makeMessage(
            id: 'm$i',
            senderId: 'owner-1',
            recipientId: 'requester-1',
            body: 'message $i',
            createdAt: kCreatedAt.add(Duration(minutes: i)),
          ),
      ];
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      expect(provider.messages, hasLength(ChatProvider.pageSize));
      expect(provider.messages.last.id, 'm44');
      expect(provider.hasMoreOlder, isTrue);

      await provider.loadOlder();

      expect(provider.messages, hasLength(45));
      expect(provider.messages.first.id, 'm0');
      expect(provider.hasMoreOlder, isFalse);
      // The second request used the oldest loaded message as its cursor.
      expect(chat.pageCursors.last, chat.history[15].createdAt);
    });
  });

  group('feedback banner', () {
    FeedbackModel someFeedback() => FeedbackModel(
      id: 'f1',
      requestId: 'req-1',
      postId: 'post-1',
      fromUserId: 'requester-1',
      toUserId: 'owner-1',
      rating: 5,
      createdAt: kCreatedAt,
    );

    test('checked for the requester of an accepted request', () async {
      feedback.existing = someFeedback();

      final provider = build(request: makeRequest(status: 'accepted'));
      await pumpEventQueue();

      expect(provider.feedbackGiven, isTrue);
    });

    test('not given yet when no feedback exists', () async {
      final provider = build(request: makeRequest(status: 'accepted'));
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('not checked while the request is still pending', () async {
      feedback.existing = someFeedback();

      final provider = build(request: makeRequest(status: 'pending'));
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('not checked for the owner', () async {
      auth.user = const UserModel(id: 'owner-1');
      feedback.existing = someFeedback();

      final provider = build(
        request: makeRequest(status: 'accepted'),
        otherUserId: 'requester-1',
      );
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('a failed check leaves the banner visible', () async {
      feedback.fetchError = Exception('offline');

      final provider = build(request: makeRequest(status: 'accepted'));
      await pumpEventQueue();

      expect(provider.feedbackGiven, isFalse);
    });

    test('markFeedbackGiven hides the banner', () async {
      final provider = build(request: makeRequest(status: 'accepted'));
      await pumpEventQueue();

      provider.markFeedbackGiven();

      expect(provider.feedbackGiven, isTrue);
    });
  });
}
