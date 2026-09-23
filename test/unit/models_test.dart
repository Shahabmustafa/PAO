import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pao/features/add_item/data/model/post_model.dart';
import 'package:pao/features/auth/data/model/user_model.dart';
import 'package:pao/features/chat/data/model/message_model.dart';
import 'package:pao/features/feedback/data/model/feedback_model.dart';
import 'package:pao/features/home/domain/filter_options.dart';
import 'package:pao/features/home/domain/product.dart';
import 'package:pao/features/requests/data/model/request_model.dart';
import 'package:pao/features/settings/data/model/profile_model.dart';
import 'package:pao/features/wishlist/data/model/wishlist_item_model.dart';

import '../helpers/fakes.dart';

void main() {
  group('PostModel.fromJson', () {
    test('maps every field', () {
      final post = PostModel.fromJson(postJson());

      expect(post.id, 'post-1');
      expect(post.userId, 'owner-1');
      expect(post.title, 'Wireless Headphones');
      expect(post.description, 'Barely used');
      expect(post.category, 'Electronics');
      expect(post.condition, 'Old');
      expect(post.address, 'House 5, Street 2');
      expect(post.imageUrls, ['https://img/1.png', 'https://img/2.png']);
      expect(post.isGiven, isFalse);
      expect(post.createdAt, kCreatedAt);
    });

    test('applies defaults for null optional columns', () {
      final post = PostModel.fromJson(
        postJson(
          description: null,
          category: null,
          condition: null,
          address: null,
          imageUrls: null,
          isGiven: null,
        ),
      );

      expect(post.description, isNull);
      expect(post.category, isNull);
      expect(post.condition, 'New');
      expect(post.address, isNull);
      expect(post.imageUrls, isEmpty);
      expect(post.isGiven, isFalse);
    });

    test('reads is_given = true', () {
      expect(PostModel.fromJson(postJson(isGiven: true)).isGiven, isTrue);
    });

    test('throws when a required column is missing', () {
      final json = postJson()..remove('title');
      expect(() => PostModel.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('throws on an unparseable created_at', () {
      final json = postJson()..['created_at'] = 'not-a-date';
      expect(() => PostModel.fromJson(json), throwsFormatException);
    });
  });

  group('RequestModel', () {
    test('fromJson maps every field', () {
      final request = RequestModel.fromJson(requestJson());

      expect(request.id, 'req-1');
      expect(request.postId, 'post-1');
      expect(request.requesterId, 'requester-1');
      expect(request.ownerId, 'owner-1');
      expect(request.status, 'pending');
      expect(request.createdAt, kCreatedAt);
    });

    test('status helpers', () {
      expect(makeRequest(status: 'pending').isPending, isTrue);
      expect(makeRequest(status: 'pending').isAccepted, isFalse);
      expect(makeRequest(status: 'accepted').isAccepted, isTrue);
      expect(makeRequest(status: 'accepted').isPending, isFalse);
      expect(makeRequest(status: 'closed').isPending, isFalse);
      expect(makeRequest(status: 'closed').isAccepted, isFalse);
    });

    test('copyWith changes only the status', () {
      final original = makeRequest();
      final accepted = original.copyWith(status: 'accepted');

      expect(accepted.status, 'accepted');
      expect(accepted.id, original.id);
      expect(accepted.postId, original.postId);
      expect(accepted.requesterId, original.requesterId);
      expect(accepted.ownerId, original.ownerId);
      expect(accepted.createdAt, original.createdAt);
      expect(original.status, 'pending', reason: 'original is immutable');
    });

    test('copyWith with no arguments keeps the status', () {
      expect(makeRequest(status: 'closed').copyWith().status, 'closed');
    });
  });

  group('MessageModel.fromJson', () {
    test('maps every field', () {
      final message = MessageModel.fromJson({
        'id': 'm1',
        'request_id': 'r1',
        'sender_id': 's1',
        'recipient_id': 's2',
        'body': 'Assalam o Alaikum',
        'created_at': kCreatedAt.toIso8601String(),
      });

      expect(message.id, 'm1');
      expect(message.requestId, 'r1');
      expect(message.senderId, 's1');
      expect(message.recipientId, 's2');
      expect(message.body, 'Assalam o Alaikum');
      expect(message.createdAt, kCreatedAt);
    });
  });

  group('FeedbackModel.fromJson', () {
    Map<String, dynamic> json({String? comment = 'Great!'}) => {
      'id': 'f1',
      'request_id': 'r1',
      'post_id': 'p1',
      'from_user_id': 'u1',
      'to_user_id': 'u2',
      'rating': 5,
      'comment': comment,
      'created_at': kCreatedAt.toIso8601String(),
    };

    test('maps every field', () {
      final feedback = FeedbackModel.fromJson(json());

      expect(feedback.id, 'f1');
      expect(feedback.requestId, 'r1');
      expect(feedback.postId, 'p1');
      expect(feedback.fromUserId, 'u1');
      expect(feedback.toUserId, 'u2');
      expect(feedback.rating, 5);
      expect(feedback.comment, 'Great!');
      expect(feedback.createdAt, kCreatedAt);
    });

    test('comment is optional', () {
      expect(FeedbackModel.fromJson(json(comment: null)).comment, isNull);
    });
  });

  group('ProfileModel.fromJson', () {
    test('maps every field', () {
      final profile = ProfileModel.fromJson({
        'id': 'u1',
        'full_name': 'Ayesha Khan',
        'email': 'ayesha@example.com',
        'phone': '+923001234567',
        'bio': 'Books lover',
        'avatar_url': 'https://img/a.png',
      });

      expect(profile.id, 'u1');
      expect(profile.fullName, 'Ayesha Khan');
      expect(profile.email, 'ayesha@example.com');
      expect(profile.phone, '+923001234567');
      expect(profile.bio, 'Books lover');
      expect(profile.avatarUrl, 'https://img/a.png');
    });

    test('everything except id is optional', () {
      final profile = ProfileModel.fromJson({'id': 'u1'});

      expect(profile.fullName, isNull);
      expect(profile.email, isNull);
      expect(profile.phone, isNull);
      expect(profile.bio, isNull);
      expect(profile.avatarUrl, isNull);
    });
  });

  group('WishlistItemModel.fromJson', () {
    test('maps every field, note optional', () {
      final withNote = WishlistItemModel.fromJson({
        'id': 'w1',
        'user_id': 'u1',
        'post_id': 'p1',
        'title': 'Bike',
        'note': 'Sports',
      });
      expect(withNote.postId, 'p1');
      expect(withNote.title, 'Bike');
      expect(withNote.note, 'Sports');

      final withoutNote = WishlistItemModel.fromJson({
        'id': 'w2',
        'user_id': 'u1',
        'post_id': 'p2',
        'title': 'Lamp',
      });
      expect(withoutNote.note, isNull);
    });
  });

  group('UserModel', () {
    test('fromSupabaseUser reads name and avatar from user metadata', () {
      final user = UserModel.fromSupabaseUser(
        makeSupabaseUser(
          id: 'u1',
          email: 'a@b.com',
          metadata: {'full_name': 'Ali', 'avatar_url': 'https://img/a.png'},
        ),
      );

      expect(user.id, 'u1');
      expect(user.email, 'a@b.com');
      expect(user.fullName, 'Ali');
      expect(user.avatarUrl, 'https://img/a.png');
    });

    test('fromSupabaseUser tolerates missing metadata', () {
      final user = UserModel.fromSupabaseUser(makeSupabaseUser());

      expect(user.fullName, isNull);
      expect(user.avatarUrl, isNull);
    });

    test('toJson / fromJson round-trip', () {
      const original = UserModel(
        id: 'u1',
        email: 'a@b.com',
        fullName: 'Ali',
        avatarUrl: 'https://img/a.png',
      );
      final copy = UserModel.fromJson(original.toJson());

      expect(copy.toJson(), original.toJson());
      expect(original.toJson(), {
        'id': 'u1',
        'email': 'a@b.com',
        'full_name': 'Ali',
        'avatar_url': 'https://img/a.png',
      });
    });
  });

  group('Product', () {
    Product product({bool isGiven = false, List<String>? urls}) => Product(
      id: 'p1',
      name: 'Lamp',
      category: 'Home & Living',
      color: Colors.green,
      description: 'Desk lamp',
      condition: 'Old',
      images: [Uint8List.fromList([1, 2, 3])],
      imageUrls: urls ?? const [],
      userId: 'u1',
      isGiven: isGiven,
    );

    test('defaults', () {
      const p = Product(
        id: 'x',
        name: 'n',
        category: 'c',
        color: Colors.red,
      );

      expect(p.description, '');
      expect(p.condition, 'New');
      expect(p.images, isEmpty);
      expect(p.imageUrls, isEmpty);
      expect(p.userId, isNull);
      expect(p.isGiven, isFalse);
    });

    test('imageUrl is the first remote image, or null', () {
      expect(product(urls: ['a', 'b']).imageUrl, 'a');
      expect(product().imageUrl, isNull);
    });

    test('copyWith(isGiven) preserves all other fields', () {
      final original = product(urls: ['a']);
      final given = original.copyWith(isGiven: true);

      expect(given.isGiven, isTrue);
      expect(given.id, original.id);
      expect(given.name, original.name);
      expect(given.category, original.category);
      expect(given.color, original.color);
      expect(given.description, original.description);
      expect(given.condition, original.condition);
      expect(given.images, original.images);
      expect(given.imageUrls, original.imageUrls);
      expect(given.userId, original.userId);
      expect(original.isGiven, isFalse);
    });

    test('copyWith() with no argument keeps isGiven', () {
      expect(product(isGiven: true).copyWith().isGiven, isTrue);
    });

    test('condition list', () {
      expect(kProductConditions, ['New', 'Used', 'Old']);
    });
  });

  group('FilterOptions', () {
    test('defaults have no active filters', () {
      const filters = FilterOptions();

      expect(filters.sortBy, 'Newest');
      expect(filters.condition, 'All');
      expect(filters.category, 'All');
      expect(filters.activeCount, 0);
    });

    test('activeCount counts condition and category', () {
      expect(const FilterOptions(condition: 'New').activeCount, 1);
      expect(const FilterOptions(category: 'Books').activeCount, 1);
      expect(
        const FilterOptions(condition: 'Old', category: 'Toys').activeCount,
        2,
      );
    });

    test('activeCount counts a non-default sort', () {
      expect(const FilterOptions(sortBy: 'Oldest').activeCount, 1);
      expect(
        const FilterOptions(
          sortBy: 'Oldest',
          condition: 'New',
          category: 'Books',
        ).activeCount,
        3,
      );
    });

    test('copyWith replaces only the given fields', () {
      const base = FilterOptions(condition: 'New', category: 'Books');
      final changed = base.copyWith(condition: 'Old');

      expect(changed.condition, 'Old');
      expect(changed.category, 'Books');
      expect(changed.sortBy, 'Newest');
      expect(base.condition, 'New');
    });

    test('condition filters offer All plus every product condition', () {
      expect(kConditionFilters, ['All', 'New', 'Used', 'Old']);
      expect(kSortOptions, contains('Newest'));
    });
  });
}
