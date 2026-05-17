class MirrorStatus {
  final bool isConnected;
  final String? alarm;
  final String? location;
  final String? currentPhrase;
  final String? weather;
  final String? currentTime;

  MirrorStatus({
    this.isConnected = false,
    this.alarm,
    this.location,
    this.currentPhrase,
    this.weather,
    this.currentTime,
  });

  MirrorStatus copyWith({
    bool? isConnected,
    String? alarm,
    String? location,
    String? currentPhrase,
    String? weather,
    String? currentTime,
  }) {
    return MirrorStatus(
      isConnected: isConnected ?? this.isConnected,
      alarm: alarm ?? this.alarm,
      location: location ?? this.location,
      currentPhrase: currentPhrase ?? this.currentPhrase,
      weather: weather ?? this.weather,
      currentTime: currentTime ?? this.currentTime,
    );
  }
}
