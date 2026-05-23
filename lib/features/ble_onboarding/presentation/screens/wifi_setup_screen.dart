import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repository/ble_repository.dart';
import '../../models/wifi_credentials.dart';

class WifiSetupScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final BleRepository bleRepository;

  const WifiSetupScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.bleRepository,
  });

  @override
  State<WifiSetupScreen> createState() => _WifiSetupScreenState();
}

class _WifiSetupScreenState extends State<WifiSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSending = false;
  bool _obscurePassword = true;
  String _deviceStatus = 'Ожидание ввода';
  StreamSubscription<String>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _subscribeToDeviceStatus();
  }

  void _subscribeToDeviceStatus() {
    _statusSubscription = widget.bleRepository.deviceStatusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _deviceStatus = _mapStatusToMessage(status);
        if (status == 'connected' || status == 'wrong_password' || status == 'error') {
          _isSending = false;
        }
      });

      if (status == 'connected') {
        _showSuccessAndClose();
      } else if (status == 'wrong_password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Неверный пароль Wi-Fi. Попробуйте снова.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (status == 'error') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка подключения к Wi-Fi. Проверьте имя сети и попробуйте снова.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    });
  }

  String _mapStatusToMessage(String status) {
    switch (status) {
      case 'connecting':
        return 'Устройство подключается к Wi-Fi...';
      case 'connected':
        return 'Успешное подключение к Wi-Fi!';
      case 'wrong_password':
        return 'Неверный пароль Wi-Fi';
      case 'error':
        return 'Ошибка подключения. Проверьте имя сети и пароль.';
      case 'no_internet':
        return 'Подключено, но нет доступа к интернету';
      default:
        return 'Статус: $status';
    }
  }

  void _showSuccessAndClose() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Подключено!'),
          ],
        ),
        content: const Text(
          'Умное зеркало успешно подключено к Wi-Fi.\n\n'
          'Хотите переключиться на другую сеть?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetForNetworkSwitch();
            },
            child: const Text('Сменить сеть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('Готово'),
          ),
        ],
      ),
    );
  }

  void _resetForNetworkSwitch() {
    setState(() {
      _isSending = false;
      _ssidController.clear();
      _passwordController.clear();
      _deviceStatus = 'Введите данные новой сети';
    });
  }

  Future<void> _sendCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _deviceStatus = 'Отправка данных...';
    });

    try {
      final credentials = WifiCredentials(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );

      await widget.bleRepository.sendWifiCredentials(credentials);

      if (mounted) {
        setState(() {
          _deviceStatus = 'Данные отправлены. Ожидание устройства...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _deviceStatus = 'Ошибка отправки: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки данных: $e')),
        );
      }
    }
  }

  Future<void> _disconnect() async {
    await widget.bleRepository.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Wi-Fi — ${widget.deviceName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
            tooltip: 'Отключить',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth_connected,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Подключено к ${widget.deviceName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                        Text(
                          'Идентификатор: ${widget.deviceId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ssidController,
                decoration: const InputDecoration(
                  labelText: 'Имя сети Wi-Fi',
                  hintText: 'Введите имя сети Wi-Fi',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите имя сети Wi-Fi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Пароль Wi-Fi',
                  hintText: 'Введите пароль Wi-Fi',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите пароль Wi-Fi';
                  }
                  if (value.length < 8) {
                    return 'Пароль должен быть не менее 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Статус устройства',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_isSending)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          if (_isSending) const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _deviceStatus,
                              style: TextStyle(
                              color: _deviceStatus.contains('Ошибка')
                                  ? Colors.red
                                  : _deviceStatus.contains('Успеш')
                                      ? Colors.green
                                      : Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSending ? null : _sendCredentials,
                icon: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'Отправка...' : 'Подключить / Сменить сеть'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSending ? null : _disconnect,
                icon: const Icon(Icons.cancel),
                label: const Text('Отключить'),
              ),
            ],
          ),
        ),
    );
  }
}
