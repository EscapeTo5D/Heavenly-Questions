class Article {
  final int id;
  final String title;
  final String content;
  final String imageUrl;
  final String author;
  final DateTime publishDate;
  final int viewCount;
  final int likeCount;

  Article({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    required this.author,
    required this.publishDate,
    required this.viewCount,
    required this.likeCount,
  });

  // 从JSON转换为Article对象
  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      imageUrl: json['imageUrl'],
      author: json['author'],
      publishDate: DateTime.parse(json['publishDate']),
      viewCount: json['viewCount'],
      likeCount: json['likeCount'],
    );
  }

  // 将Article对象转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'imageUrl': imageUrl,
      'author': author,
      'publishDate': publishDate.toIso8601String(),
      'viewCount': viewCount,
      'likeCount': likeCount,
    };
  }
}
