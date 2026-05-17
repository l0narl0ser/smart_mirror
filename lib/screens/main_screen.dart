import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _mqttService = MqttService();
  final _alarmHourController = TextEditingController();
  final _alarmMinuteController = TextEditingController();
  final _phraseController = TextEditingController();

  String _connectionStatus = 'Not connected';
  String? _currentAlarm;
  String? _currentPhrase;
  String _lastMessage = '';

  @override
  void initState() {
    super.initState();
    _mqttService.onConnectionStatusChanged = (status) {
      setState(() {
        _connectionStatus = status;
      });
    };
    _mqttService.onMessageReceived = (topic, payload) {
      setState(() {
        _lastMessage = '[$topic] $payload';
      });
    };
  }

  Future<void> _setAlarm() async {
    final hour = int.tryParse(_alarmHourController.text);
    final minute = int.tryParse(_alarmMinuteController.text);

    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid time. Hour: 0-23, Minute: 0-59')),
      );
      return;
    }

    try {
      await _mqttService.setAlarm(hour, minute);
      if (!mounted) return;
      setState(() {
        _currentAlarm = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alarm set to $_currentAlarm')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set alarm: $e')),
      );
    }
  }

  Future<void> _clearAlarm() async {
    try {
      await _mqttService.clearAlarm();
      if (!mounted) return;
      setState(() {
        _currentAlarm = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alarm cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear alarm: $e')),
      );
    }
  }

  Future<void> _setPhrase() async {
    final phrase = _phraseController.text.trim();
    if (phrase.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phrase')),
      );
      return;
    }

    setState(() {
      _currentPhrase = phrase;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phrase set')),
    );
  }

  Future<void> _clearPhrase() async {
    setState(() {
      _currentPhrase = null;
      _phraseController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Phrase cleared')),
    );
  }

  Future<void> _restartDevice() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Device'),
        content: const Text('Are you sure you want to restart the smart mirror?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _mqttService.restartDevice();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restart command sent')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restart: $e')),
        );
      }
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
    if (result == true) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Mirror Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildConnectionStatus(),
          const SizedBox(height: 24),
          _buildAlarmCard(),
          const SizedBox(height: 16),
          _buildPhraseCard(),
          const SizedBox(height: 16),
          _buildDeviceCard(),
          const SizedBox(height: 16),
          _buildMessageLog(),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _mqttService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _mqttService.isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Connection Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_connectionStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Alarm',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _alarmHourController,
                    decoration: const InputDecoration(
                      labelText: 'Hour (0-23)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _alarmMinuteController,
                    decoration: const InputDecoration(
                      labelText: 'Minute (0-59)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _setAlarm,
                    child: const Text('Set Alarm'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAlarm,
                    child: const Text('Clear Alarm'),
                  ),
                ),
              ],
            ),
            if (_currentAlarm != null) ...[
              const SizedBox(height: 8),
              Text('Current alarm: $_currentAlarm'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhraseCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phrase',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phraseController,
              decoration: const InputDecoration(
                labelText: 'Enter phrase',
                hintText: 'Type your phrase here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _setPhrase,
                    child: const Text('Set Phrase'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearPhrase,
                    child: const Text('Clear'),
                  ),
                ),
              ],
            ),
            if (_currentPhrase != null) ...[
              const SizedBox(height: 8),
              Text(
                'Current phrase: $_currentPhrase',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Control',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _restartDevice,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Restart Device'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageLog() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _lastMessage.isEmpty ? 'No messages received' : _lastMessage,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _alarmHourController.dispose();
    _alarmMinuteController.dispose();
    _phraseController.dispose();
    super.dispose();
  }
}
