import 'dart:typed_data';
import 'package:flutter/material.dart';

const List<String> kProductConditions = ['New', 'Used', 'Old'];

class Product {
  final String id;
  final String name;
  final String category;
  final Color color;
  final String description;
  final String condition;
  final List<Uint8List> images;
  final List<String> imageUrls;
  final String? userId;
  final bool isGiven;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.color,
    this.description = '',
    this.condition = 'New',
    this.images = const [],
    this.imageUrls = const [],
    this.userId,
    this.isGiven = false,
  });

  /// First remote image, if any — used where only a single preview image
  /// is needed (grid cards, request tiles).
  String? get imageUrl => imageUrls.isNotEmpty ? imageUrls.first : null;

  Product copyWith({bool? isGiven}) {
    return Product(
      id: id,
      name: name,
      category: category,
      color: color,
      description: description,
      condition: condition,
      images: images,
      imageUrls: imageUrls,
      userId: userId,
      isGiven: isGiven ?? this.isGiven,
    );
  }
}
