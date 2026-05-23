import 'package:flutter/material.dart';
import '../../../../services/mqtt_service.dart';

class ConnectionStatusScreen extends StatefulWidget {
  const ConnectionStatusScreen({super.key});

  @override
  State<ConnectionStatusScreen> createState() => _ConnectionStatusScreenState();
}

class _ConnectionStatusScreenState extends State<ConnectionStatusScreen> {
  final _mqttService = MqttService();
  String _mqttStatus = 'Не подключено';
  final String _bleStatus = 'Не подключено';

  @override
  void initState() {
    super.initState();
    _mqttService.onConnectionStatusChanged = (status) {
      if (mounted) {
        setState(() {
          _mqttStatus = status;
        });
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _mqttService.isConnected
                              ? Icons.cloud_done
                              : Icons.cloud_off,
                          color: _mqttService.isConnected
                              ? Colors.green
                              : Colors.red,
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Подключение',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      _mqttStatus,
                      style: TextStyle(
                      color: _mqttStatus.contains('Ошибка')
                          ? Colors.red
                          : _mqttStatus.contains('Подключено')
                              ? Colors.green
                              : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.bluetooth,
                          color: Colors.blue[700],
                          size: 32,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Bluetooth',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text(
                      _bleStatus,
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
