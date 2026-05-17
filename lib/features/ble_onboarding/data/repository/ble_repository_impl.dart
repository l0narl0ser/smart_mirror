import 'dart:async';
import '../service/ble_service.dart';
import '../../models/ble_device_model.dart';
import '../../models/wifi_credentials.dart';
import 'ble_repository.dart';

class BleRepositoryImpl implements BleRepository {
  final BleService _bleService = BleService();

  @override
  Future<void> init() async {
    await _bleService.init();
  }

  @override
  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    await _bleService.startScan(timeout: timeout);
  }

  @override
  Future<void> stopScan() async {
    await _bleService.stopScan();
  }

  @override
  Stream<List<BleDeviceModel>> get scanResultsStream => _bleService.scanResultsStream;

  @override
  Stream<String> get deviceStatusStream => _bleService.deviceStatusStream;

  @override
  Future<bool> connectToDevice(String deviceId) async {
    return await _bleService.connectToDevice(deviceId);
  }

  @override
  Future<void> sendWifiCredentials(WifiCredentials credentials) async {
    await _bleService.sendWifiCredentials(credentials);
  }

  @override
  Future<void> disconnect() async {
    await _bleService.disconnect();
  }

  @override
  bool get isConnected => _bleService.isConnected;

  @override
  String? get connectedDeviceId => _bleService.connectedDevice?.remoteId.str;

  @override
  void dispose() {
    _bleService.dispose();
  }
}
