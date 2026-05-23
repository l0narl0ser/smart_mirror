import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/repository/ble_repository.dart';
import '../../data/repository/ble_repository_impl.dart';
import '../../models/ble_device_model.dart';
import 'wifi_setup_screen.dart';

class BleScanScreen extends StatefulWidget {
  const BleScanScreen({super.key});

  @override
  State<BleScanScreen> createState() => _BleScanScreenState();
}

class _BleScanScreenState extends State<BleScanScreen> {
  final BleRepository _bleRepository = BleRepositoryImpl();
  final List<BleDeviceModel> _devices = [];
  bool _isScanning = false;
  bool _permissionsGranted = false;
  bool _locationServicesEnabled = false;
  String _statusMessage = 'Проверьте разрешения для начала сканирования';
  StreamSubscription<List<BleDeviceModel>>? _scanSubscription;
  Timer? _scanTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    final locationEnabled = await Permission.location.serviceStatus.isEnabled;

    setState(() {
      _locationServicesEnabled = locationEnabled;
    });

    if (bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted &&
        locationEnabled) {
      setState(() {
        _permissionsGranted = true;
        _statusMessage = 'Нажмите сканирование для поиска устройств';
      });
    } else {
      setState(() {
        _permissionsGranted = false;
        if (!locationEnabled) {
          _statusMessage = 'Служба геолокации отключена. Для поиска устройств по Bluetooth необходимо включить GPS.';
        } else {
          _statusMessage = 'Разрешения отклонены. Включите их в настройках.';
        }
      });
    }
  }

  Future<void> _enableLocationServices() async {
    await openAppSettings();
    await Future.delayed(const Duration(seconds: 2));
    await _checkPermissions();
  }

  Future<void> _startScan() async {
    final locationEnabled = await Permission.location.serviceStatus.isEnabled;
    if (!locationEnabled) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Требуется геолокация'),
            content: const Text(
              'Для поиска устройств по Bluetooth на Android необходимо включить службу геолокации. '
              'Пожалуйста, включите её в настройках устройства.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _enableLocationServices();
                },
                child: const Text('Открыть настройки'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!_permissionsGranted) {
      await _checkPermissions();
      if (!_permissionsGranted) return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = 'Сканирование устройств...';
    });

    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted && _isScanning) {
        _handleScanTimeout();
      }
    });

    _scanSubscription?.cancel();
    _scanSubscription = _bleRepository.scanResultsStream.listen((devices) {
      if (mounted) {
        setState(() {
          _devices.clear();
          _devices.addAll(devices);
        });
        debugPrint('BLE Scan: found ${devices.length} device(s)');
        for (final d in devices) {
          debugPrint('  - ${d.name} (${d.id}) RSSI: ${d.rssi}');
        }
      }
    });

    await _bleRepository.startScan(timeout: const Duration(seconds: 10));

    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      setState(() {
        _isScanning = false;
        if (_devices.isEmpty) {
          _statusMessage = 'Устройства не найдены. Убедитесь, что устройство включено.';
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Устройства не найдены.'),
              duration: Duration(seconds: 3),
            ),
          );
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _statusMessage = 'Нажмите сканирование для поиска устройств';
              });
            }
          });
        } else {
          _statusMessage = 'Найдено устройств: ${_devices.length}';
        }
      });
    }
  }

  Future<void> _handleScanTimeout() async {
    await _stopScan();
    if (mounted) {
      setState(() {
        _statusMessage = 'Устройства не найдены за 30 секунд. Попробуйте снова.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Тайм-аут сканирования: устройства не найдены.'),
          duration: Duration(seconds: 3),
        ),
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _statusMessage = 'Нажмите сканирование для поиска устройств';
          });
        }
      });
    }
  }

  Future<void> _stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    await _bleRepository.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Сканирование остановлено';
      });
    }
  }

  Future<void> _connectToDevice(BleDeviceModel device) async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Подключение к ${device.name}...';
      });

      final connected = await _bleRepository.connectToDevice(device.id);

      if (connected && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WifiSetupScreen(
              deviceId: device.id,
              deviceName: device.name,
              bleRepository: _bleRepository,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Ошибка подключения: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка подключения: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanTimeoutTimer?.cancel();
    _bleRepository.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск устройств'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      _locationServicesEnabled
                          ? Icons.location_on
                          : Icons.location_off,
                      color: _locationServicesEnabled
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: _statusMessage.contains('Ошибка')
                              ? Colors.red
                              : _statusMessage.contains('Найдено')
                                  ? Colors.green
                                  : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (!_locationServicesEnabled) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _enableLocationServices,
                    icon: const Icon(Icons.settings),
                    label: const Text('Включить геолокацию'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (!_locationServicesEnabled || !_permissionsGranted)
                            ? null
                            : _isScanning
                                ? _stopScan
                                : _startScan,
                        icon: _isScanning
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.bluetooth_searching),
                        label: Text(_isScanning ? 'Остановить' : 'Начать сканирование'),
                      ),
                    ),
                    if (!_permissionsGranted) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _checkPermissions,
                        icon: const Icon(Icons.settings),
                        label: const Text('Разрешения'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bluetooth_disabled,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isScanning ? 'Поиск...' : 'Устройства не найдены',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (context, index) {
                      final device = _devices[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(device.name),
                          subtitle: Text(
                            'Идентификатор: ${device.id}\nСигнал: ${device.rssi}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToDevice(device),
                            child: const Text('Подключить'),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
