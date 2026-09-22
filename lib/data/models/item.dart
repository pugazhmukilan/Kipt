import 'dart:convert';
import 'package:equatable/equatable.dart';

class Item extends Equatable {
  static const Object _notesUnset = Object();

  final int? id;
  final String title;
  final int? categoryId;
  final List<String> tags;
  final String? notes;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Item({
    this.id,
    required this.title,
    this.categoryId,
    this.tags = const [],
    this.notes,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category_id': categoryId,
      'tags': jsonEncode(tags),
      'notes': notes,
      'favorite': favorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = [];
    if (map['tags'] != null && (map['tags'] as String).isNotEmpty) {
      try {
        parsedTags = List<String>.from(
          jsonDecode(map['tags'] as String) as List,
        );
      } catch (_) {
        parsedTags = [];
      }
    }
    return Item(
      id: map['id'] as int?,
      title: map['title'] as String,
      categoryId: map['category_id'] as int?,
      tags: parsedTags,
      notes: map['notes'] as String?,
      favorite: (map['favorite'] as int? ?? 0) == 1,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
    );
  }

  /// Lenient date parsing: an old/corrupt row with a missing or invalid
  /// timestamp must not crash the whole item list.
  static DateTime _parseDateTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Item copyWith({
    int? id,
    String? title,
    int? categoryId,
    List<String>? tags,
    Object? notes = _notesUnset,
    bool? favorite,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      notes: identical(notes, _notesUnset) ? this.notes : notes as String?,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory Item.fromJson(Map<String, dynamic> json) => Item.fromMap(json);

  @override
  List<Object?> get props => [
    id,
    title,
    categoryId,
    tags,
    notes,
    favorite,
    createdAt,
    updatedAt,
  ];

  @override
  String toString() => 'Item{id: $id, title: $title, categoryId: $categoryId}';
}
