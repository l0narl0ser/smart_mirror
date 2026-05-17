class BleDeviceModel {
  final String id;
  final String name;
  final int rssi;

  const BleDeviceModel({
    required this.id,
    required this.name,
    required this.rssi,
  });

  BleDeviceModel copyWith({
    String? id,
    String? name,
    int? rssi,
  }) {
    return BleDeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BleDeviceModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
