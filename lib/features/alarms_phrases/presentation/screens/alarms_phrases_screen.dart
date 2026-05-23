import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../services/mqtt_service.dart';
import '../../models/alarm_model.dart';
import '../../models/phrase_model.dart';
import '../widgets/ios_time_picker.dart';

class AlarmsPhrasesScreen extends StatefulWidget {
  const AlarmsPhrasesScreen({super.key});

  @override
  State<AlarmsPhrasesScreen> createState() => _AlarmsPhrasesScreenState();
}

class _AlarmsPhrasesScreenState extends State<AlarmsPhrasesScreen> with SingleTickerProviderStateMixin {
  final _mqttService = MqttService();
  final _uuid = const Uuid();
  late TabController _tabController;

  final List<AlarmModel> _alarms = [];
  final List<PhraseModel> _phrases = [];
  static const int maxPhrases = 20;

  int _selectedHour = 7;
  int _selectedMinute = 0;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _addAlarm() async {
    int hour = _selectedHour;
    int minute = _selectedMinute;

    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                const Text(
                  'Новый будильник',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Сохранить', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            IosTimePicker(
              initialHour: hour,
              initialMinute: minute,
              onHourChanged: (h) => hour = h,
              onMinuteChanged: (m) => minute = m,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == true) {
      final alarm = AlarmModel(
        id: _uuid.v4(),
        hour: hour,
        minute: minute,
      );
      setState(() {
        _alarms.add(alarm);
      });
      _sendAlarmToMqtt(alarm);
    }
  }

  Future<void> _editAlarm(AlarmModel alarm) async {
    int hour = alarm.hour;
    int minute = alarm.minute;

    final result = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Отмена'),
                ),
                const Text(
                  'Изменить будильник',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Сохранить', style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            IosTimePicker(
              initialHour: hour,
              initialMinute: minute,
              onHourChanged: (h) => hour = h,
              onMinuteChanged: (m) => minute = m,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() {
        final index = _alarms.indexWhere((a) => a.id == alarm.id);
        if (index != -1) {
          _alarms[index] = AlarmModel(
            id: alarm.id,
            hour: hour,
            minute: minute,
            isEnabled: alarm.isEnabled,
          );
        }
      });
      _sendAlarmToMqtt(
        AlarmModel(id: alarm.id, hour: hour, minute: minute, isEnabled: alarm.isEnabled),
      );
    }
  }

  void _toggleAlarm(AlarmModel alarm) {
    setState(() {
      final index = _alarms.indexWhere((a) => a.id == alarm.id);
      if (index != -1) {
        _alarms[index].isEnabled = !_alarms[index].isEnabled;
      }
    });
    if (alarm.isEnabled) {
      _sendAlarmToMqtt(alarm);
    } else {
      _sendClearAlarmToMqtt(alarm);
    }
  }

  void _deleteAlarm(AlarmModel alarm) {
    setState(() {
      _alarms.removeWhere((a) => a.id == alarm.id);
    });
    _sendClearAlarmToMqtt(alarm);
  }

  Future<void> _sendAlarmToMqtt(AlarmModel alarm) async {
    try {
      await _mqttService.setAlarm(alarm.hour, alarm.minute);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка установки будильника: $e')),
        );
      }
    }
  }

  Future<void> _sendClearAlarmToMqtt(AlarmModel alarm) async {
    try {
      await _mqttService.clearAlarm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сброса будильника: $e')),
        );
      }
    }
  }

  void _addPhrase() {
    if (_phrases.length >= maxPhrases) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Максимум $maxPhrases фраз')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Новая фраза'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Введите фразу...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 30,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    _phrases.add(PhraseModel(id: _uuid.v4(), text: text));
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  void _editPhrase(PhraseModel phrase) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: phrase.text);
        return AlertDialog(
          title: const Text('Изменить фразу'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Введите фразу...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            maxLength: 30,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  setState(() {
                    phrase.text = text;
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void _deletePhrase(PhraseModel phrase) {
    setState(() {
      _phrases.removeWhere((p) => p.id == phrase.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Будильники и фразы'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.alarm), text: 'Будильники'),
            Tab(icon: Icon(Icons.format_quote), text: 'Фразы'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlarmsTab(),
          _buildPhrasesTab(),
        ],
      ),
    );
  }

  Widget _buildAlarmsTab() {
    return Column(
      children: [
        Expanded(
          child: _alarms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.alarm_add, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет будильников',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(
                          alarm.formattedTime,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w300),
                        ),
                        subtitle: Text(
                          alarm.isEnabled ? 'Включен' : 'Отключен',
                          style: TextStyle(
                            color: alarm.isEnabled ? Colors.green : Colors.grey,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: alarm.isEnabled,
                              onChanged: (_) => _toggleAlarm(alarm),
                              activeThumbColor: Colors.green,
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editAlarm(alarm),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteAlarm(alarm),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addAlarm,
              icon: const Icon(Icons.add),
              label: const Text('Добавить будильник'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhrasesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_phrases.length}/$maxPhrases фраз',
                style: TextStyle(color: Colors.grey[600]),
              ),
              ElevatedButton.icon(
                onPressed: _phrases.length >= maxPhrases ? null : _addPhrase,
                icon: const Icon(Icons.add),
                label: const Text('Добавить фразу'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _phrases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.format_quote, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет фраз',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _phrases.length,
                  itemBuilder: (context, index) {
                    final phrase = _phrases[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: Text(
                          phrase.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editPhrase(phrase),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deletePhrase(phrase),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
