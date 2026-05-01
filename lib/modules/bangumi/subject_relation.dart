class BangumiSubjectRelation {
  final int id;
  final int type;
  final String name;
  final String nameCn;
  final String image;
  final String relation;

  BangumiSubjectRelation({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.image,
    required this.relation,
  });

  factory BangumiSubjectRelation.fromJson(Map<String, dynamic> json) {
    String parseImage(dynamic imageField) {
      if (imageField is Map<String, dynamic>) {
        return imageField['large']?.toString() ?? '';
      }
      if (imageField is String) {
        return imageField;
      }
      return '';
    }

    return BangumiSubjectRelation(
      id: json['id'] ?? 0,
      type: json['type'] ?? 0,
      name: json['name'] ?? '',
      nameCn: json['name_cn'] ?? '',
      image: parseImage(json['images'] ?? json['image'] ?? ''),
      relation: json['relation'] ?? '',
    );
  }
}
