import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _brokerController = TextEditingController();
  final _portController = TextEditingController();
  final _topicPrefixController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isConnecting = false;
  String _connectionStatus = 'Не подключено';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = SettingsService();
    await settings.init();
    setState(() {
      _brokerController.text = settings.broker;
      _portController.text = settings.port.toString();
      _topicPrefixController.text = settings.topicPrefix;
      _clientIdController.text = settings.clientId;
      _usernameController.text = settings.username ?? '';
      _passwordController.text = settings.password ?? '';
    });
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = 'Подключение...';
    });

    try {
      final settings = SettingsService();
      await settings.saveSettings(
        broker: _brokerController.text,
        port: int.parse(_portController.text),
        topicPrefix: _topicPrefixController.text,
        clientId: _clientIdController.text,
        username: _usernameController.text.isEmpty ? null : _usernameController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );

      final mqtt = MqttService();
      await mqtt.connect(
        broker: _brokerController.text,
        port: int.parse(_portController.text),
        topicPrefix: _topicPrefixController.text,
        clientId: _clientIdController.text,
        username: _usernameController.text.isEmpty ? null : _usernameController.text,
        password: _passwordController.text.isEmpty ? null : _passwordController.text,
      );

      setState(() {
        _connectionStatus = 'Подключено к ${_brokerController.text}:${_portController.text}';
      });

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Ошибка подключения: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _brokerController,
                decoration: const InputDecoration(
                  labelText: 'Адрес сервера',
                  hintText: 'localhost',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите адрес сервера';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Порт',
                  hintText: '1883',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите порт';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port <= 0 || port > 65535) {
                    return 'Введите корректный порт (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _topicPrefixController,
                decoration: const InputDecoration(
                  labelText: 'Префикс топика',
                  hintText: 'mirror/',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите префикс топика';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Идентификатор клиента',
                  hintText: 'smart_mirror_ui',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите идентификатор клиента';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Имя пользователя (необязательно)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль (необязательно)',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              Text(
                _connectionStatus,
                style: TextStyle(
                  color: _connectionStatus.contains('Ошибка')
                      ? Colors.red
                      : _connectionStatus.contains('Подключено')
                          ? Colors.green
                          : Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                child: _isConnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Подключить'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _brokerController.dispose();
    _portController.dispose();
    _topicPrefixController.dispose();
    _clientIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
