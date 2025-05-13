class Question {
  final int? id;
  final String title;
  final String content;
  final List<String> options;
  final int correctOption;
  final String? explanation;
  final String category;
  final int difficulty;
  final bool isFavorite;
  final DateTime createdAt;

  Question({
    this.id,
    required this.title,
    required this.content,
    required this.options,
    required this.correctOption,
    this.explanation,
    required this.category,
    required this.difficulty,
    this.isFavorite = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'options': options.join('||'), // 使用双竖线分隔选项
      'correct_option': correctOption,
      'explanation': explanation,
      'category': category,
      'difficulty': difficulty,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'],
      title: map['title'],
      content: map['content'],
      options: (map['options'] as String).split('||'),
      correctOption: map['correct_option'],
      explanation: map['explanation'],
      category: map['category'],
      difficulty: map['difficulty'],
      isFavorite: map['is_favorite'] == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Question copyWith({
    int? id,
    String? title,
    String? content,
    List<String>? options,
    int? correctOption,
    String? explanation,
    String? category,
    int? difficulty,
    bool? isFavorite,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      options: options ?? this.options,
      correctOption: correctOption ?? this.correctOption,
      explanation: explanation ?? this.explanation,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
