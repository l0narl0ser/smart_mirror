enum BleConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  sendingCredentials,
  waitingForWifi,
  wifiConnected,
  wifiWrongPassword,
  error,
}

class BleStatus {
  final BleConnectionState connectionState;
  final String message;
  final String? deviceId;

  const BleStatus({
    this.connectionState = BleConnectionState.disconnected,
    this.message = '',
    this.deviceId,
  });

  BleStatus copyWith({
    BleConnectionState? connectionState,
    String? message,
    String? deviceId,
  }) {
    return BleStatus(
      connectionState: connectionState ?? this.connectionState,
      message: message ?? this.message,
      deviceId: deviceId ?? this.deviceId,
    );
  }
}
