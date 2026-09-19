import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/settings/data/model/profile_model.dart';
import 'package:pao/features/settings/presentation/provider/edit_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeProfileRepository profiles;
  late FakeAuthRepository auth;
  late EditProfileProvider provider;

  setUp(() {
    profiles = FakeProfileRepository();
    auth = FakeAuthRepository(
      user: const UserModel(
        id: 'u1',
        email: 'me@example.com',
        avatarUrl: 'https://img/auth-avatar.png',
      ),
    );
    provider = EditProfileProvider(repository: profiles, authRepository: auth);
  });

  group('loadProfile', () {
    test('returns null (and no request) when signed out', () async {
      auth.user = null;

      expect(await provider.loadProfile(), isNull);
      expect(provider.isLoading, isFalse);
    });

    test('returns the stored profile and prefers its avatar', () async {
      profiles.profile = const ProfileModel(
        id: 'u1',
        fullName: 'Ali',
        avatarUrl: 'https://img/db-avatar.png',
      );

      final profile = await provider.loadProfile();

      expect(profile!.fullName, 'Ali');
      expect(provider.avatarUrl, 'https://img/db-avatar.png');
      expect(provider.isLoading, isFalse);
    });

    test('falls back to the auth avatar when the profile has none', () async {
      profiles.profile = const ProfileModel(id: 'u1', fullName: 'Ali');

      await provider.loadProfile();

      expect(provider.avatarUrl, 'https://img/auth-avatar.png');
    });

    test('a failed lookup returns null and stops loading', () async {
      profiles.fetchError = Exception('offline');

      expect(await provider.loadProfile(), isNull);
      expect(provider.isLoading, isFalse);
    });
  });

  group('uploadAvatar', () {
    test('stores the new URL', () async {
      await provider.uploadAvatar(Uint8List.fromList([1, 2, 3]));

      expect(provider.avatarUrl, 'https://img/new-avatar.png');
      expect(provider.errorMessage, isNull);
      expect(provider.isUploadingAvatar, isFalse);
    });

    test('requires a signed-in user', () async {
      auth.user = null;

      await provider.uploadAvatar(Uint8List.fromList([1]));

      expect(provider.errorMessage, 'You must be logged in to update your photo.');
    });

    test('a failure keeps the old avatar and shows a message', () async {
      profiles.uploadError = Exception('too large');
      await provider.loadProfile(); // picks up the auth avatar
      final before = provider.avatarUrl;

      await provider.uploadAvatar(Uint8List.fromList([1]));

      expect(provider.avatarUrl, before);
      expect(provider.errorMessage, 'Failed to update photo. Please try again.');
      expect(provider.isUploadingAvatar, isFalse);
    });
  });

  group('save', () {
    test('saves and reports success without an email change', () async {
      final ok = await provider.save(
        fullName: 'Ali Khan',
        email: 'me@example.com',
        phone: '0300',
        bio: 'hi',
      );

      expect(ok, isTrue);
      expect(provider.emailChangeNeedsConfirmation, isFalse);
      final call = profiles.saveCalls.single;
      expect(call['userId'], 'u1');
      expect(call['fullName'], 'Ali Khan');
      expect(call['currentEmail'], 'me@example.com');
      expect(call['phone'], '0300');
      expect(provider.isSaving, isFalse);
    });

    test('flags that a changed email needs confirmation', () async {
      final ok = await provider.save(
        fullName: 'Ali',
        email: 'new@example.com',
      );

      expect(ok, isTrue);
      expect(provider.emailChangeNeedsConfirmation, isTrue);
      expect(profiles.saveCalls.single['email'], 'new@example.com');
    });

    test('requires a signed-in user', () async {
      auth.user = null;

      final ok = await provider.save(fullName: 'Ali', email: 'a@b.com');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'You must be logged in to update your profile.');
      expect(profiles.saveCalls, isEmpty);
    });

    test('shows the auth message (e.g. email already in use)', () async {
      profiles.saveError = const AuthException('Email address already in use');

      final ok = await provider.save(fullName: 'Ali', email: 'taken@b.com');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Email address already in use');
      expect(provider.isSaving, isFalse);
    });

    test('hides unexpected errors', () async {
      profiles.saveError = Exception('db down');

      final ok = await provider.save(fullName: 'Ali', email: 'me@example.com');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('saving toggles on and off', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isSaving));

      await provider.save(fullName: 'Ali', email: 'me@example.com');

      expect(states, [true, false]);
    });
  });
}
