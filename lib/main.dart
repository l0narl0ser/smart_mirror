import 'package:flutter/material.dart';
import 'services/settings_service.dart';
import 'features/ble_onboarding/data/service/ble_service.dart';
import 'features/alarms_phrases/services/alarms_phrases_service.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  await BleService().init();
  await AlarmsPhrasesService().init();
  runApp(const MyApp());
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
