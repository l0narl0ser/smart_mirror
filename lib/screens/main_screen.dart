import 'package:flutter/material.dart';
import '../services/mqtt_service.dart';
import 'settings_screen.dart';
import '../features/ble_onboarding/presentation/screens/ble_scan_screen.dart';
import '../features/ble_onboarding/presentation/screens/connection_status_screen.dart';
import '../features/alarms_phrases/presentation/screens/alarms_phrases_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _mqttService = MqttService();

  String _connectionStatus = 'Not connected';
  String _lastMessage = '';
  int _selectedIndex = 0;

  final List<Widget> _tabs = [];

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
    _tabs.addAll([
      _buildControlTab(),
      const AlarmsPhrasesScreen(),
      const BleScanScreen(),
      const ConnectionStatusScreen(),
    ]);
  }

  Widget _buildControlTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildConnectionStatus(),
        const SizedBox(height: 24),
        _buildDeviceCard(),
        const SizedBox(height: 16),
        _buildMessageLog(),
      ],
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
        title: const Text('Smart Mirror'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Control',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching),
            selectedIcon: Icon(Icons.bluetooth),
            label: 'BLE Setup',
          ),
          NavigationDestination(
            icon: Icon(Icons.signal_cellular_alt),
            selectedIcon: Icon(Icons.signal_cellular_alt),
            label: 'Status',
          ),
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
}
