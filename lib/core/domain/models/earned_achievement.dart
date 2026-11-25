class EarnedAchievement {
  final String id;
  final String title;
  final String description;
  final int iconCode;
  final DateTime earnedDate;

  const EarnedAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconCode,
    required this.earnedDate,
  });

  factory EarnedAchievement.fromMap(Map<String, dynamic> map) {
    return EarnedAchievement(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      iconCode: (map['iconCode'] as num?)?.toInt() ?? 0,
      earnedDate: DateTime.parse(map['earnedDate'] as String),
    );
  }
}
