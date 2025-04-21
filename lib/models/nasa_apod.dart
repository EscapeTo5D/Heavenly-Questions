class NasaApod {
  final String title;
  final String explanation;
  final String url;
  final String? hdurl;
  final String mediaType;
  final String date;

  // 新增字段
  final Map<String, dynamic>? resource;
  final Map<String, dynamic>? imageSet;
  final String? planet;
  final bool? conceptTags;
  final String? thumbnailUrl;
  final String? copyright;
  final String? serviceVersion;

  String? translatedTitle;
  String? translatedExplanation;

  NasaApod({
    required this.title,
    required this.explanation,
    required this.url,
    this.hdurl,
    required this.mediaType,
    required this.date,
    this.resource,
    this.imageSet,
    this.planet,
    this.conceptTags,
    this.thumbnailUrl,
    this.copyright,
    this.serviceVersion,
    this.translatedTitle,
    this.translatedExplanation,
  });

  factory NasaApod.fromJson(Map<String, dynamic> json) {
    return NasaApod(
      title: json['title'] ?? '',
      explanation: json['explanation'] ?? '',
      url: json['url'] ?? '',
      hdurl: json['hdurl'],
      mediaType: json['media_type'] ?? 'image',
      date: json['date'] ?? '',
      resource: json['resource'],
      imageSet: json['image_set'],
      planet: json['planet'],
      conceptTags: json['concept_tags'],
      thumbnailUrl: json['thumbnail_url'],
      copyright: json['copyright'],
      serviceVersion: json['service_version'],
    );
  }

  // 获取显示的标题（优先使用翻译后的标题）
  String get displayTitle => translatedTitle ?? title;

  // 获取显示的说明（优先使用翻译后的说明）
  String get displayExplanation => translatedExplanation ?? explanation;
}
