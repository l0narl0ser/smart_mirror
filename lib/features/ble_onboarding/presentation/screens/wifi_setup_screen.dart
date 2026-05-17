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
  String _deviceStatus = 'Waiting for input';
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
      });

      if (status == 'connected') {
        _showSuccessAndClose();
      } else if (status == 'wrong_password') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wrong Wi-Fi password. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  String _mapStatusToMessage(String status) {
    switch (status) {
      case 'connecting':
        return 'Device is connecting to Wi-Fi...';
      case 'connected':
        return 'Successfully connected to Wi-Fi!';
      case 'wrong_password':
        return 'Wrong Wi-Fi password';
      default:
        return 'Status: $status';
    }
  }

  void _showSuccessAndClose() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
        content: const Text('Smart Mirror connected to Wi-Fi successfully!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(true);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCredentials() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSending = true;
      _deviceStatus = 'Sending credentials...';
    });

    try {
      final credentials = WifiCredentials(
        ssid: _ssidController.text.trim(),
        password: _passwordController.text,
      );

      await widget.bleRepository.sendWifiCredentials(credentials);

      if (mounted) {
        setState(() {
          _deviceStatus = 'Credentials sent. Waiting for device...';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _deviceStatus = 'Failed to send: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send credentials: $e')),
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
        title: Text('Wi-Fi Setup - ${widget.deviceName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: _disconnect,
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            'Connected to ${widget.deviceName}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Device ID: ${widget.deviceId}',
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
                  labelText: 'Wi-Fi Network Name (SSID)',
                  hintText: 'Enter your Wi-Fi network name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.wifi),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Wi-Fi network name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Wi-Fi Password',
                  hintText: 'Enter your Wi-Fi password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Wi-Fi password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
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
                        'Device Status',
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
                                color: _deviceStatus.contains('Failed')
                                    ? Colors.red
                                    : _deviceStatus.contains('Success')
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
                label: Text(_isSending ? 'Sending...' : 'Send Wi-Fi Credentials'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isSending ? null : _disconnect,
                icon: const Icon(Icons.cancel),
                label: const Text('Disconnect'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
