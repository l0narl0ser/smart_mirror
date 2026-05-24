import 'dart:async';
import '../../models/ble_device_model.dart';
import '../../models/wifi_credentials.dart';

abstract class BleRepository {
  Future<void> init();
  Future<void> startScan({Duration timeout});
  Future<void> stopScan();
  Stream<List<BleDeviceModel>> get scanResultsStream;
  Stream<String> get deviceStatusStream;
  Stream<String> get deviceIpStream;
  Stream<String> getDeviceIpStreamWithReplay();

  Future<bool> connectToDevice(String deviceId);
  Future<void> sendWifiCredentials(WifiCredentials credentials);
  Future<void> disconnect();

  bool get isConnected;
  String? get connectedDeviceId;
  String? get lastReceivedIp;

  void dispose();
}
