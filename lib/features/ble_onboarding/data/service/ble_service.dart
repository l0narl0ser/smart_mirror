import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../models/ble_device_model.dart';
import '../../models/wifi_credentials.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  static const String serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String writeCharacteristicUuid = 'abcdef01-1234-5678-1234-56789abcdef0';
  static const String statusCharacteristicUuid = 'abcdef02-1234-5678-1234-56789abcdef0';
  static const String targetDeviceName = 'SMART_MIRROR';

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _statusCharacteristic;
  StreamSubscription<List<int>>? _statusSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  final _scanResultsController = StreamController<List<BleDeviceModel>>.broadcast();
  Stream<List<BleDeviceModel>> get scanResultsStream => _scanResultsController.stream;

  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionStateStream => _connectionStateController.stream;

  final _deviceStatusController = StreamController<String>.broadcast();
  Stream<String> get deviceStatusStream => _deviceStatusController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  Future<void> init() async {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        _handleDisconnect();
      }
    });
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 10)}) async {
    // Cancel any previous scan subscription to prevent memory leaks
    _scanSubscription?.cancel();

    // No name/UUID filter — show all BLE devices so the user can pick their Pi
    // regardless of what name it advertises (hostname vs alias).
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final devices = results
          .where((r) => r.device.platformName.isNotEmpty)
          .map((result) => BleDeviceModel(
                id: result.device.remoteId.str,
                name: result.device.platformName,
                rssi: result.rssi,
              ))
          .toList();
      _scanResultsController.add(devices);
    });
  }

  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    await FlutterBluePlus.stopScan();
  }

  Future<bool> connectToDevice(String deviceId) async {
    try {
      _connectedDevice = BluetoothDevice.fromId(deviceId);

      await _connectedDevice!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      _connectedDevice!.connectionState.listen((state) {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect();
        }
      });

      await _discoverServices();
      return true;
    } catch (e) {
      _connectedDevice = null;
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    final services = await _connectedDevice!.discoverServices();

    for (final service in services) {
      if (service.uuid.str.toLowerCase() == serviceUuid.toLowerCase()) {
        for (final characteristic in service.characteristics) {
          if (characteristic.uuid.str.toLowerCase() == writeCharacteristicUuid.toLowerCase()) {
            _writeCharacteristic = characteristic;
          }
          if (characteristic.uuid.str.toLowerCase() == statusCharacteristicUuid.toLowerCase()) {
            _statusCharacteristic = characteristic;
            await _setupStatusNotifications();
          }
        }
      }
    }
  }

  Future<void> _setupStatusNotifications() async {
    if (_statusCharacteristic == null) return;

    await _statusCharacteristic!.setNotifyValue(true);

    _statusSubscription?.cancel();
    _statusSubscription = _statusCharacteristic!.lastValueStream.listen((value) {
      if (value.isNotEmpty) {
        try {
          final response = utf8.decode(value);
          final json = jsonDecode(response) as Map<String, dynamic>;
          final status = json['status'] as String? ?? '';
          _deviceStatusController.add(status);
        } catch (e) {
          _deviceStatusController.add('error');
        }
      }
    });
  }

  Future<void> sendWifiCredentials(WifiCredentials credentials) async {
    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic not found');
    }

    final bytes = credentials.toBytes();
    await _writeCharacteristic!.write(bytes, withoutResponse: false);
  }

  Future<void> disconnect() async {
    await _statusSubscription?.cancel();
    await _connectedDevice?.disconnect();
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _connectedDevice = null;
    _writeCharacteristic = null;
    _statusCharacteristic = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  void dispose() {
    _scanSubscription?.cancel();
    _statusSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    _scanResultsController.close();
    _connectionStateController.close();
    _deviceStatusController.close();
    disconnect();
  }
}
