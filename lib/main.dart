import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/mqtt_service.dart';
import 'features/ble_onboarding/data/service/ble_service.dart';
import 'features/alarms_phrases/services/alarms_phrases_service.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await BleService().init();
  await AlarmsPhrasesService().init();
  await _tryAutoConnectMqtt();
  runApp(const MyApp());
}

Future<void> _tryAutoConnectMqtt() async {
  final savedIp = SettingsService().savedIp;
  debugPrint('[MAIN] 🔍 Автоподключение MQTT: savedIp=$savedIp');
  if (savedIp != null && savedIp.isNotEmpty) {
    try {
      debugPrint('[MAIN] 🔄 Попытка подключения к MQTT...');
      await MqttService().connect();
      debugPrint('[MAIN] ✅ MQTT подключён');
    } catch (e) {
      debugPrint('[MAIN] ❌ Auto MQTT connection failed: $e');
    }
  } else {
    debugPrint('[MAIN] ⚠️ savedIp отсутствует, автоподключение пропущено');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Умное Зеркало',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}
