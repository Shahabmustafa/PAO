import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/chat/presentation/provider/chat_provider.dart';
import 'package:pao/features/feedback/data/model/feedback_model.dart';
import 'package:pao/features/requests/data/model/request_model.dart';

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
    test('starts loading, then shows what the stream delivers', () async {
      final provider = build();
      expect(provider.isLoading, isTrue);

      chat.controller.add([makeMessage(id: 'a'), makeMessage(id: 'b')]);
      await pumpEventQueue();

      expect(provider.isLoading, isFalse);
      expect(provider.messages.map((m) => m.id), ['a', 'b']);
    });

    test('live updates replace the list and notify', () async {
      final provider = build();
      var notified = 0;
      provider.addListener(() => notified++);

      chat.controller.add([makeMessage(id: 'a')]);
      chat.controller.add([makeMessage(id: 'a'), makeMessage(id: 'b')]);
      await pumpEventQueue();

      expect(provider.messages, hasLength(2));
      expect(notified, greaterThanOrEqualTo(2));
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
