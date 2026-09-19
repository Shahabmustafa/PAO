import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/auth/presentation/provider/forgot_password_provider.dart';
import 'package:pao/features/auth/presentation/provider/login_provider.dart';
import 'package:pao/features/auth/presentation/provider/reset_password_provider.dart';
import 'package:pao/features/auth/presentation/provider/signup_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  group('LoginProvider', () {
    late LoginProvider provider;
    setUp(() => provider = LoginProvider(repository: auth));

    test('starts idle', () {
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('returns true and calls the repository on success', () async {
      final ok = await provider.login(email: 'a@b.com', password: 'secret1');

      expect(ok, isTrue);
      expect(provider.errorMessage, isNull);
      expect(auth.loginCalls.single.email, 'a@b.com');
      expect(auth.loginCalls.single.password, 'secret1');
    });

    test('shows loading while in flight and clears it after', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.login(email: 'a@b.com', password: 'secret1');

      expect(states, [true, false]);
      expect(provider.isLoading, isFalse);
    });

    test('surfaces the server message for a bad login', () async {
      auth.loginError = const AuthException('Invalid login credentials');

      final ok = await provider.login(email: 'a@b.com', password: 'wrong');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Invalid login credentials');
    });

    test('shows a friendly message when offline', () async {
      auth.loginError = AuthRetryableFetchException(
        message: 'ClientException with SocketException',
      );

      await provider.login(email: 'a@b.com', password: 'secret1');

      expect(provider.errorMessage, contains('No internet connection'));
      expect(provider.errorMessage, isNot(contains('SocketException')));
    });

    test('hides unexpected errors behind a generic message', () async {
      auth.loginError = StateError('secret internal detail');

      final ok = await provider.login(email: 'a@b.com', password: 'secret1');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Something went wrong. Please try again.');
      expect(provider.errorMessage, isNot(contains('secret internal')));
    });

    test('clears a previous error on the next attempt', () async {
      auth.loginError = const AuthException('nope');
      await provider.login(email: 'a@b.com', password: 'x');
      expect(provider.errorMessage, isNotNull);

      auth.loginError = null;
      await provider.login(email: 'a@b.com', password: 'secret1');

      expect(provider.errorMessage, isNull);
    });
  });

  group('SignupProvider', () {
    late SignupProvider provider;
    setUp(() => provider = SignupProvider(repository: auth));

    test('success when a session is issued', () async {
      final result = await provider.signUp(
        fullName: 'Ali',
        email: 'a@b.com',
        password: 'secret1',
      );

      expect(result, SignupResult.success);
      expect(auth.registerCalls.single.fullName, 'Ali');
      expect(provider.errorMessage, isNull);
    });

    test('needsEmailConfirmation when no session is issued', () async {
      auth.registerNeedsConfirmation = true;

      final result = await provider.signUp(
        fullName: 'Ali',
        email: 'a@b.com',
        password: 'secret1',
      );

      expect(result, SignupResult.needsEmailConfirmation);
      expect(provider.errorMessage, isNull);
    });

    test('failure surfaces the auth message (e.g. duplicate email)', () async {
      auth.registerError = const AuthException('User already registered');

      final result = await provider.signUp(
        fullName: 'Ali',
        email: 'a@b.com',
        password: 'secret1',
      );

      expect(result, SignupResult.failure);
      expect(provider.errorMessage, 'User already registered');
    });

    test('failure hides unexpected errors', () async {
      auth.registerError = Exception('db down');

      final result = await provider.signUp(
        fullName: 'Ali',
        email: 'a@b.com',
        password: 'secret1',
      );

      expect(result, SignupResult.failure);
      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('loading toggles on and off', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.signUp(fullName: 'A', email: 'a@b.com', password: 'secret1');

      expect(states, [true, false]);
    });
  });

  group('ForgotPasswordProvider', () {
    late ForgotPasswordProvider provider;
    setUp(() => provider = ForgotPasswordProvider(repository: auth));

    test('marks the email as sent', () async {
      await provider.sendResetEmail('a@b.com');

      expect(provider.emailSent, isTrue);
      expect(provider.errorMessage, isNull);
      expect(auth.resetCalls, ['a@b.com']);
    });

    test('auth failure keeps emailSent false and shows the message', () async {
      auth.resetError = const AuthException('Rate limit exceeded');

      await provider.sendResetEmail('a@b.com');

      expect(provider.emailSent, isFalse);
      expect(provider.errorMessage, 'Rate limit exceeded');
    });

    test('unexpected failure shows the generic message', () async {
      auth.resetError = Exception('boom');

      await provider.sendResetEmail('a@b.com');

      expect(provider.emailSent, isFalse);
      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('loading toggles on and off', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.sendResetEmail('a@b.com');

      expect(states, [true, false]);
    });
  });

  group('ResetPasswordProvider', () {
    late ResetPasswordProvider provider;
    setUp(() => provider = ResetPasswordProvider(repository: auth));

    test('starts idle', () {
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
    });

    test('updates the password through the repository', () async {
      final ok = await provider.updatePassword('newsecret');

      expect(ok, isTrue);
      expect(provider.errorMessage, isNull);
      expect(auth.updatePasswordCalls, ['newsecret']);
    });

    test('auth failure returns false and shows the message', () async {
      auth.updatePasswordError = const AuthException('Session expired');

      final ok = await provider.updatePassword('newsecret');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Session expired');
    });

    test('reusing the old password is explained in plain words', () async {
      auth.updatePasswordError = const AuthException(
        'New password should be different from the old password.',
        code: 'same_password',
      );

      await provider.updatePassword('oldsecret');

      expect(
        provider.errorMessage,
        'Your new password must be different from your old one.',
      );
    });

    test('unexpected failure shows the generic message', () async {
      auth.updatePasswordError = Exception('boom');

      final ok = await provider.updatePassword('newsecret');

      expect(ok, isFalse);
      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('loading toggles on and off', () async {
      final states = <bool>[];
      provider.addListener(() => states.add(provider.isLoading));

      await provider.updatePassword('newsecret');

      expect(states, [true, false]);
    });

    test('cancel signs the recovery session out', () async {
      auth.user = UserModel(id: 'u1', email: 'a@b.com');

      await provider.cancel();

      expect(auth.isLoggedIn, isFalse);
    });
  });
}
