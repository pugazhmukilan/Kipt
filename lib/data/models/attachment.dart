import 'package:equatable/equatable.dart';

class Attachment extends Equatable {
  final int? id;
  final int itemId;
  final String path;
  final bool isPhoto;
  final String mimetype;
  final DateTime addedAt;
  final double? aspectRatio;

  const Attachment({
    this.id,
    required this.itemId,
    required this.path,
    required this.isPhoto,
    required this.mimetype,
    required this.addedAt,
    this.aspectRatio,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'path': path,
      'is_photo': isPhoto ? 1 : 0,
      'mimetype': mimetype,
      'added_at': addedAt.toIso8601String(),
      'aspect_ratio': aspectRatio,
    };
  }

  factory Attachment.fromMap(Map<String, dynamic> map) {
    return Attachment(
      id: map['id'] as int?,
      itemId: map['item_id'] as int,
      path: map['path'] as String,
      isPhoto: (map['is_photo'] as int? ?? 1) == 1,
      mimetype: map['mimetype'] as String? ?? 'image/jpeg',
      addedAt: _parseDateTime(map['added_at']),
      aspectRatio: (map['aspect_ratio'] as num?)?.toDouble(),
    );
  }

  /// Lenient date parsing so a corrupt timestamp cannot crash item loads.
  static DateTime _parseDateTime(Object? raw) {
    if (raw is String && raw.isNotEmpty) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Attachment copyWith({
    int? id,
    int? itemId,
    String? path,
    bool? isPhoto,
    String? mimetype,
    DateTime? addedAt,
    double? aspectRatio,
  }) {
    return Attachment(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      path: path ?? this.path,
      isPhoto: isPhoto ?? this.isPhoto,
      mimetype: mimetype ?? this.mimetype,
      addedAt: addedAt ?? this.addedAt,
      aspectRatio: aspectRatio ?? this.aspectRatio,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Attachment.fromJson(Map<String, dynamic> json) =>
      Attachment.fromMap(json);

  @override
  List<Object?> get props => [
    id,
    itemId,
    path,
    isPhoto,
    mimetype,
    addedAt,
    aspectRatio,
  ];
}
