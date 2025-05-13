import 'package:mongo_dart/mongo_dart.dart' show ObjectId;

class QuizQuestion {
  final String? id; // MongoDB ObjectId as String
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final String categoryName; // Changed from category
  final String? imageAssetPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isFavorite; // New field for favorites
  final int difficulty; // New field for difficulty (e.g., 1-5)

  QuizQuestion({
    this.id,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.categoryName,
    this.imageAssetPath,
    this.createdAt,
    this.updatedAt,
    this.isFavorite = false, // Default to false
    this.difficulty = 1, // Default to 1 (e.g., easy)
  });

  QuizQuestion copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctOptionIndex,
    String? explanation,
    String? categoryName,
    String? imageAssetPath,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isFavorite,
    int? difficulty,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctOptionIndex: correctOptionIndex ?? this.correctOptionIndex,
      explanation: explanation ?? this.explanation,
      categoryName: categoryName ?? this.categoryName,
      imageAssetPath: imageAssetPath ?? this.imageAssetPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
      difficulty: difficulty ?? this.difficulty,
    );
  }

  // From MongoDB document (Map) to QuizQuestion object
  static QuizQuestion fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).toHexString()
          : map['_id'] as String?,
      questionText: map['questionText'] as String,
      options: List<String>.from(map['options'] as List<dynamic>),
      correctOptionIndex: map['correctOptionIndex'] as int,
      explanation: map['explanation'] as String,
      categoryName: map['categoryName'] as String,
      imageAssetPath: map['imageAssetPath'] as String?,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null),
      updatedAt: map['updatedAt'] is DateTime
          ? map['updatedAt'] as DateTime
          : (map['updatedAt'] != null
              ? DateTime.tryParse(map['updatedAt'].toString())
              : null),
      isFavorite: map['isFavorite'] as bool? ??
          false, // Handle null from DB, default to false
      difficulty:
          map['difficulty'] as int? ?? 1, // Handle null from DB, default to 1
    );
  }

  // From QuizQuestion object to MongoDB document (Map)
  // Note: _id is typically not included when inserting, MongoDB generates it.
  // Include it if you are updating an existing document by its _id.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'questionText': questionText,
      'options': options, // MongoDB can store lists directly
      'correctOptionIndex': correctOptionIndex,
      'explanation': explanation,
      'categoryName': categoryName,
      'imageAssetPath': imageAssetPath,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isFavorite': isFavorite,
      'difficulty': difficulty,
    };
    if (id != null) {
      // map['_id'] = ObjectId.fromHexString(id!); // Use this if you need to pass ObjectId
    }
    return map;
  }

  @override
  String toString() {
    return 'QuizQuestion{id: $id, questionText: $questionText, options: $options, correctOptionIndex: $correctOptionIndex, categoryName: $categoryName, imageAssetPath: $imageAssetPath, createdAt: $createdAt, updatedAt: $updatedAt, isFavorite: $isFavorite, difficulty: $difficulty}';
  }
}

// QuizCategory model for MongoDB
class QuizCategory {
  final String? id; // MongoDB ObjectId as String
  final String name;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  QuizCategory({
    this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  QuizCategory copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuizCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // From MongoDB document (Map) to QuizCategory object
  static QuizCategory fromMap(Map<String, dynamic> map) {
    return QuizCategory(
      id: map['_id'] is ObjectId
          ? (map['_id'] as ObjectId).toHexString()
          : map['_id'] as String?,
      name: map['name'] as String,
      description: map['description'] as String?,
      createdAt: map['createdAt'] is DateTime
          ? map['createdAt'] as DateTime
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString())
              : null),
      updatedAt: map['updatedAt'] is DateTime
          ? map['updatedAt'] as DateTime
          : (map['updatedAt'] != null
              ? DateTime.tryParse(map['updatedAt'].toString())
              : null),
    );
  }

  // From QuizCategory object to MongoDB document (Map)
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
    if (id != null) {
      // map['_id'] = ObjectId.fromHexString(id!);
    }
    return map;
  }

  @override
  String toString() {
    return 'QuizCategory{id: $id, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
