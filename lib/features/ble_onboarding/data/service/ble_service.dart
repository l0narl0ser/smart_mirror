import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../../services/mqtt_service.dart';
import '../../../../services/settings_service.dart';
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

  final _deviceIpController = StreamController<String>.broadcast();
  Stream<String> get deviceIpStream => _deviceIpController.stream;

  String? _lastReceivedIp;
  String? get lastReceivedIp => _lastReceivedIp;
  bool _mqttUpdateInProgress = false;

  Stream<String> getDeviceIpStreamWithReplay() {
    final controller = StreamController<String>.broadcast();

    if (_lastReceivedIp != null) {
      controller.add(_lastReceivedIp!);
    }

    final subscription = _deviceIpController.stream.listen(
      (ip) => controller.add(ip),
      onError: (e) => controller.addError(e),
    );

    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };

    return controller.stream;
  }

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

    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidUsesFineLocation: true,
      withServices: [Guid(serviceUuid)],
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final devices = results.map((result) {
        final platformName = result.device.platformName;
        final advName = result.advertisementData.advName;
        
        final name = platformName.isNotEmpty
            ? platformName
            : advName.isNotEmpty
                ? advName
                : result.device.remoteId.str;
        
        return BleDeviceModel(
          id: result.device.remoteId.str,
          name: name,
          rssi: result.rssi,
        );
      }).toList();
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
      debugPrint('[BLE] 🔗 Подключение к устройству: $deviceId');
      _connectedDevice = BluetoothDevice.fromId(deviceId);

      await _connectedDevice!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      debugPrint('[BLE] ✅ BLE соединение установлено');

      _connectedDevice!.connectionState.listen((state) {
        debugPrint('[BLE] Состояние соединения: $state');
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] ❌ Устройство отключилось');
          _handleDisconnect();
        }
      });

      await _discoverServices();
      return true;
    } catch (e) {
      debugPrint('[BLE] ❌ Ошибка подключения: $e');
      _connectedDevice = null;
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    if (_connectedDevice == null) return;

    debugPrint('[BLE] 🔍 Discovering services...');
    final services = await _connectedDevice!.discoverServices();
    debugPrint('[BLE] Найдено сервисов: ${services.length}');

    for (final service in services) {
      debugPrint('[BLE] Сервис UUID: ${service.uuid.str}');
      if (service.uuid.str.toLowerCase() == serviceUuid.toLowerCase()) {
        debugPrint('[BLE] ✅ Найден наш сервис!');
        for (final characteristic in service.characteristics) {
          debugPrint('[BLE] Характеристика UUID: ${characteristic.uuid.str}');
          if (characteristic.uuid.str.toLowerCase() == writeCharacteristicUuid.toLowerCase()) {
            _writeCharacteristic = characteristic;
            debugPrint('[BLE] ✅ Write characteristic найдена');
          }
          if (characteristic.uuid.str.toLowerCase() == statusCharacteristicUuid.toLowerCase()) {
            _statusCharacteristic = characteristic;
            debugPrint('[BLE] ✅ Status characteristic найдена');
            await _setupStatusNotifications();
          }
        }
      }
    }
  }

  Future<void> _setupStatusNotifications() async {
    if (_statusCharacteristic == null) return;

    debugPrint('[BLE] 📡 Включаем нотификации для status characteristic...');
    await _statusCharacteristic!.setNotifyValue(true);
    debugPrint('[BLE] ✅ Нотификации включены');

    _statusSubscription?.cancel();
    _statusSubscription = _statusCharacteristic!.lastValueStream.listen((value) {
      _processStatusValue(value);
    });

    debugPrint('[BLE] 📖 Читаем текущее значение status characteristic...');
    try {
      final currentValue = await _statusCharacteristic!.read();
      debugPrint('[BLE] 📖 Прочитанное значение: $currentValue');
      if (currentValue.isNotEmpty) {
        _processStatusValue(currentValue);
      } else {
        debugPrint('[BLE] ⚠️ Прочитанное значение пустое');
      }
    } catch (e) {
      debugPrint('[BLE] ❌ Ошибка чтения: $e');
    }
  }

  void _processStatusValue(List<int> value) {
    if (value.isEmpty) return;

    debugPrint('═══════════════════════════════════════');
    debugPrint('[BLE] Получены сырые байты: $value');

    try {
      final response = utf8.decode(value);
      debugPrint('[BLE] Распарсенная строка: $response');

      final json = jsonDecode(response) as Map<String, dynamic>;
      debugPrint('[BLE] JSON: $json');

      final status = json['status'] as String? ?? '';
      final ip = json['ip'] as String? ?? '';

      debugPrint('[BLE] Статус: "${status.isEmpty ? "пусто" : status}"');
      debugPrint('[BLE] IP: "${ip.isEmpty ? "пусто" : ip}"');

      if (status.isNotEmpty) {
        _deviceStatusController.add(status);
      }

      if (status == 'connected' && ip.isNotEmpty) {
        debugPrint('[BLE] ✅ IP получен: $ip');
        if (_lastReceivedIp != ip) {
          _lastReceivedIp = ip;
          _deviceIpController.add(ip);
          _saveIpAndUpdateMqtt(ip);
        } else {
          debugPrint('[BLE] ⚠️ IP $ip уже был обработан ранее');
        }
      } else if (status == 'connected' && ip.isEmpty) {
        debugPrint('[BLE] ⚠️ Статус "connected", но IP отсутствует в ответе!');
      }

      debugPrint('═══════════════════════════════════════');
    } catch (e) {
      debugPrint('[BLE] ❌ Ошибка парсинга: $e');
      debugPrint('[BLE] Сырые данные: ${value.toString()}');
      debugPrint('═══════════════════════════════════════');
    }
  }

  Future<void> _saveIpAndUpdateMqtt(String ip) async {
    if (_mqttUpdateInProgress) {
      debugPrint('[BLE] ⚠️ MQTT update уже в процессе, пропускаем');
      return;
    }
    if (_lastReceivedIp == ip) {
      debugPrint('[BLE] ⚠️ IP $ip уже обработан, пропускаем');
      return;
    }
    
    _mqttUpdateInProgress = true;
    try {
      debugPrint('[BLE] 💾 _saveIpAndUpdateMqtt вызван с IP: $ip');
      debugPrint('[BLE] Сохранение IP в SharedPreferences...');
      await SettingsService().saveSavedIp(ip);
      debugPrint('[BLE] ✅ IP сохранён');
      debugPrint('[BLE] 🔄 Вызов MqttService().updateBrokerHost($ip)...');
      await MqttService().updateBrokerHost(ip);
      debugPrint('[BLE] ✅ MQTT обновлён на $ip');
    } catch (e, stackTrace) {
      debugPrint('[BLE] ❌ Ошибка в _saveIpAndUpdateMqtt: $e');
      debugPrint('[BLE] Stack: $stackTrace');
    } finally {
      _mqttUpdateInProgress = false;
    }
  }

  Future<void> sendWifiCredentials(WifiCredentials credentials) async {
    if (_writeCharacteristic == null) {
      throw Exception('Write characteristic not found');
    }

    final bytes = credentials.toBytes();
    debugPrint('[BLE] 📤 Отправка credentials: ${utf8.decode(bytes)}');
    await _writeCharacteristic!.write(bytes, withoutResponse: false);
    debugPrint('[BLE] ✅ Credentials отправлены');
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
    _deviceIpController.close();
    disconnect();
  }
}
