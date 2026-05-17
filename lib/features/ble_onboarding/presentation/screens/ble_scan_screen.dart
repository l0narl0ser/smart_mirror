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
  String _statusMessage = 'Check permissions to start scanning';
  StreamSubscription<List<BleDeviceModel>>? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    if (bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted) {
      setState(() {
        _permissionsGranted = true;
        _statusMessage = 'Tap scan to find devices';
      });
    } else {
      setState(() {
        _permissionsGranted = false;
        _statusMessage = 'Permissions denied. Please enable them in settings.';
      });
    }
  }

  Future<void> _startScan() async {
    if (!_permissionsGranted) {
      await _checkPermissions();
      if (!_permissionsGranted) return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _statusMessage = 'Scanning for devices...';
    });

    _scanSubscription?.cancel();
    _scanSubscription = _bleRepository.scanResultsStream.listen((devices) {
      setState(() {
        _devices.clear();
        _devices.addAll(devices);
      });
    });

    await _bleRepository.startScan(timeout: const Duration(seconds: 10));

    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = _devices.isEmpty
            ? 'No devices found. Make sure SMART_MIRROR is powered on.'
            : 'Found ${_devices.length} device(s)';
      });
    }
  }

  Future<void> _stopScan() async {
    await _bleRepository.stopScan();
    if (mounted) {
      setState(() {
        _isScanning = false;
        _statusMessage = 'Scan stopped';
      });
    }
  }

  Future<void> _connectToDevice(BleDeviceModel device) async {
    try {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Connecting to ${device.name}...';
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
          _statusMessage = 'Connection failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bleRepository.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Device Scan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  _statusMessage,
                  style: TextStyle(
                    color: _statusMessage.contains('failed')
                        ? Colors.red
                        : _statusMessage.contains('Found')
                            ? Colors.green
                            : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isScanning ? _stopScan : _startScan,
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
                        label: Text(_isScanning ? 'Stop Scan' : 'Start Scan'),
                      ),
                    ),
                    if (!_permissionsGranted) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _checkPermissions,
                        icon: const Icon(Icons.settings),
                        label: const Text('Permissions'),
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
                          _isScanning ? 'Searching...' : 'No devices found',
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
                            'ID: ${device.id}\nRSSI: ${device.rssi}',
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToDevice(device),
                            child: const Text('Connect'),
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
