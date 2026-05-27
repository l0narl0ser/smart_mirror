import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'services/mqtt_service.dart';
import 'services/location_service.dart';
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
      await _sendLocation();
    } catch (e) {
      debugPrint('[MAIN] ❌ Auto MQTT connection failed: $e');
    }
  } else {
    debugPrint('[MAIN] ⚠️ savedIp отсутствует, автоподключение пропущено');
  }
}

Future<void> _sendLocation() async {
  final location = await LocationService().getCurrentLocation();
  if (location != null) {
    await MqttService().setLocation(
      location.latitude,
      location.longitude,
      city: location.city,
    );
    debugPrint('[MAIN] ✅ Локация отправлена: ${location.latitude}, ${location.longitude}, ${location.city}');
  } else {
    debugPrint('[MAIN] ❌ Не удалось получить локацию');
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
