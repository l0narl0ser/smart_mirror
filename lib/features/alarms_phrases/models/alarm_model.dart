class AlarmModel {
  final String id;
  final int hour;
  final int minute;
  bool isEnabled;

  AlarmModel({
    required this.id,
    required this.hour,
    required this.minute,
    this.isEnabled = true,
  });

  String get formattedTime {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  AlarmModel copyWith({
    String? id,
    int? hour,
    int? minute,
    bool? isEnabled,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'isEnabled': isEnabled,
    };
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] as String,
      hour: json['hour'] as int,
      minute: json['minute'] as int,
      isEnabled: json['isEnabled'] as bool? ?? true,
    );
  }
}
