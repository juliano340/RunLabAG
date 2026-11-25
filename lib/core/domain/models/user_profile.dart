class UserProfile {
  final String name;
  final int age;
  final double weight;
  final double height;
  final String? profilePicturePath;
  final double weeklyGoal;
  final double monthlyGoal;
  final DateTime? lastGoalUpdate;
  final bool kmNotificationsEnabled;

  static const Object _unset = Object();

  UserProfile({
    required this.name,
    required this.age,
    required this.weight,
    required this.height,
    this.profilePicturePath,
    this.weeklyGoal = 20.0,
    this.monthlyGoal = 80.0,
    this.lastGoalUpdate,
    this.kmNotificationsEnabled = true,
  });

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    double? height,
    Object? profilePicturePath = _unset,
    double? weeklyGoal,
    double? monthlyGoal,
    Object? lastGoalUpdate = _unset,
    bool? kmNotificationsEnabled,
  }) {
    return UserProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      profilePicturePath: identical(profilePicturePath, _unset)
          ? this.profilePicturePath
          : profilePicturePath as String?,
      weeklyGoal: weeklyGoal ?? this.weeklyGoal,
      monthlyGoal: monthlyGoal ?? this.monthlyGoal,
      lastGoalUpdate: identical(lastGoalUpdate, _unset)
          ? this.lastGoalUpdate
          : lastGoalUpdate as DateTime?,
      kmNotificationsEnabled:
          kmNotificationsEnabled ?? this.kmNotificationsEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 'current_user',
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'profilePicturePath': profilePicturePath,
      'weeklyGoal': weeklyGoal,
      'monthlyGoal': monthlyGoal,
      'lastGoalUpdate': lastGoalUpdate?.toIso8601String(),
      'kmNotificationsEnabled': kmNotificationsEnabled ? 1 : 0,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: map['name'] ?? 'Runner',
      age: map['age'] ?? 0,
      weight: map['weight'] ?? 0.0,
      height: map['height'] ?? 0.0,
      profilePicturePath: map['profilePicturePath'],
      weeklyGoal: map['weeklyGoal'] ?? 20.0,
      monthlyGoal: map['monthlyGoal'] ?? 80.0,
      lastGoalUpdate: map['lastGoalUpdate'] != null
          ? DateTime.parse(map['lastGoalUpdate'])
          : null,
      kmNotificationsEnabled: (map['kmNotificationsEnabled'] ?? 1) == 1,
    );
  }

  double get bmi {
    if (height <= 0) return 0;
    return weight / ((height / 100) * (height / 100));
  }

  String get bmiStatus {
    double val = bmi;
    if (val < 18.5) return "Abaixo do peso";
    if (val < 25) return "Peso normal";
    if (val < 30) return "Sobrepeso";
    return "Obesidade";
  }
}
