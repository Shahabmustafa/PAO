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
    }) => MessageModel(
      id: id,
      requestId: 'req-1',
      senderId: senderId,
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

    test('a message for another request is ignored', () async {
      final provider = build();
      chat.controller.add(subscribedEvent());
      await pumpEventQueue();

      chat.controller.add(
        insertEvent(
          'x',
          MessageModel(
            id: 'x',
            requestId: 'other-request',
            senderId: 'owner-1',
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
      expect(provider.isSending, isFalse);
    });

    test(
      'the sent message shows at once and its realtime echo is not doubled',
      () async {
        final provider = build();

        await provider.sendMessage('hello');
        expect(provider.messages.map((m) => m.id), ['sent-1']);

        // Realtime then delivers the same row back to the sender.
        chat.controller.add(
          insertEvent(
            'sent-1',
            makeMessage(id: 'sent-1', senderId: 'requester-1', body: 'hello'),
          ),
        );
        await pumpEventQueue();

        expect(provider.messages.map((m) => m.id), ['sent-1']);
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

    test('a failure shows a message and re-enables sending', () async {
      chat.sendError = Exception('offline');
      final provider = build();

      await provider.sendMessage('hello');

      expect(provider.errorMessage, 'Failed to send message.');
      expect(provider.isSending, isFalse);
    });

    test('isSending is true while the message is in flight', () async {
      final provider = build();
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isSending));

      await provider.sendMessage('hello');

      expect(states.first, isTrue);
      expect(states.last, isFalse);
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
