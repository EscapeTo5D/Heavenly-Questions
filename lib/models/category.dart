class Category {
  final int? id;
  final String name;
  final String? description;
  final String? iconPath;
  final int questionCount;
  final DateTime createdAt;

  Category({
    this.id,
    required this.name,
    this.description,
    this.iconPath,
    this.questionCount = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_path': iconPath,
      'question_count': questionCount,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      iconPath: map['icon_path'],
      questionCount: map['question_count'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? description,
    String? iconPath,
    int? questionCount,
    DateTime? createdAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconPath: iconPath ?? this.iconPath,
      questionCount: questionCount ?? this.questionCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
