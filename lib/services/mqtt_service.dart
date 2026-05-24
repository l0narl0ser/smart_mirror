import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'settings_service.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  String _brokerHost = '';
  String _broker = '';
  int _port = 1883;
  String _topicPrefix = 'mirror/';
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Future<void> _initBrokerHost() async {
    final savedIp = SettingsService().savedIp;
    _brokerHost = savedIp ?? 'zompie.local';
  }

  Function(String topic, String payload)? onMessageReceived;
  Function(String status)? onConnectionStatusChanged;

  Future<String> _resolveHost(String host) async {
    final result = await InternetAddress.lookup(host);
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      return result[0].address;
    }
    throw Exception('Не удалось разрешить хост: $host');
  }

  Future<void> connect({
    String? broker,
    int? port,
    String? topicPrefix,
    String? clientId,
    String? username,
    String? password,
  }) async {
    await _initBrokerHost();
    debugPrint('[MQTT] 📋 _initBrokerHost: savedIp=${SettingsService().savedIp}, _brokerHost=$_brokerHost');
    _brokerHost = broker ?? _brokerHost;
    _port = port ?? _port;
    _topicPrefix = topicPrefix ?? _topicPrefix;

    debugPrint('[MQTT] 🔗 Подключение к брокеру: $_brokerHost:$_port');
    _broker = await _resolveHost(_brokerHost);
    debugPrint('[MQTT] 🌐 Разрешённый IP: $_broker');

    _client = MqttServerClient(_broker, clientId ?? 'smart_mirror_ui');
    _client!.port = _port;
    _client!.keepAlivePeriod = 60;
    _client!.onDisconnected = _onDisconnected;
    _client!.onConnected = _onConnected;
    _client!.secure = false;
    _client!.logging(on: true);

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId ?? 'smart_mirror_ui')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    if (username != null && username.isNotEmpty) {
      connMessage.withWillTopic('will/topic').withWillMessage('Client disconnected');
      _client!.connectionMessage = connMessage;
    } else {
      _client!.connectionMessage = connMessage;
    }

    try {
      debugPrint('[MQTT] ⏳ Вызов _client!.connect()...');
      await _client!.connect();
      debugPrint('[MQTT] ✅ _client!.connect() завершён');
    } catch (e) {
      if (_isConnected) {
        debugPrint('[MQTT] ⚠️ Исключение при connect(), но onConnected уже вызван — считаем успешным');
        return;
      }
      debugPrint('[MQTT] ❌ Ошибка подключения: $e');
      onConnectionStatusChanged?.call('Ошибка подключения: $e');
      _client!.disconnect();
      rethrow;
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] ✅ _onConnected вызван! isConnected=true');
    _isConnected = true;
    onConnectionStatusChanged?.call('Подключено к $_broker:$_port');
    _subscribe();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] 🔌 _onDisconnected вызван! isConnected=false');
    _isConnected = false;
    onConnectionStatusChanged?.call('Отключено');
  }

  void _subscribe() {
    debugPrint('[MQTT] 📥 Подписка на топик: $_topicPrefix#');
    _client!.subscribe('$_topicPrefix#', MqttQos.atMostOnce);
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      final topic = messages[0].topic;
      debugPrint('[MQTT] 📨 Получено сообщение: topic=$topic, payload=$payload');
      onMessageReceived?.call(topic, payload);
    });
  }

  Future<void> publish(String topic, Map<String, dynamic> payload) async {
    debugPrint('[MQTT] 📤 publish: topic=$_topicPrefix$topic, payload=${jsonEncode(payload)}');
    debugPrint('[MQTT] 📊 isConnected=$_isConnected, _client=${_client != null ? "not null" : "null"}');
    if (!_isConnected || _client == null) {
      debugPrint('[MQTT] ❌ Нет подключения к серверу! isConnected=$_isConnected, _client=${_client != null}');
      throw Exception('Нет подключения к серверу');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    debugPrint('[MQTT] 📤 Отправка...');
    _client!.publishMessage('$_topicPrefix$topic', MqttQos.atMostOnce, builder.payload!);
    debugPrint('[MQTT] ✅ publishMessage вызван');
  }

  Future<void> setAlarm(int hour, int minute) async {
    await publish('alarm/set', {'hour': hour, 'minute': minute});
  }

  Future<void> clearAlarm() async {
    await publish('alarm/clear', {});
  }

  Future<void> setLocation(double latitude, double longitude, {String? city}) async {
    final payload = {
      'latitude': latitude,
      'longitude': longitude,
      'city': city ?? '',
    };
    await publish('location/set', payload);
  }

  Future<void> restartDevice() async {
    await publish('device/restart', {});
  }

  void disconnect() {
    _client?.disconnect();
    _isConnected = false;
  }

  Future<void> updateBrokerHost(String newHost) async {
    debugPrint('[MQTT] 🔄 updateBrokerHost вызван: новый хост=$newHost');
    debugPrint('[MQTT] 📊 Текущий _brokerHost=$_brokerHost, isConnected=$_isConnected');
    _brokerHost = newHost;
    await SettingsService().saveSavedIp(newHost);
    debugPrint('[MQTT] ✅ IP сохранён в SharedPreferences');

    debugPrint('[MQTT] 🔄 Подключение к новому хосту $newHost...');
    if (_isConnected) {
      debugPrint('[MQTT] Сначала отключаемся...');
      disconnect();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    try {
      await connect();
      debugPrint('[MQTT] ✅ Подключено к $newHost');
    } catch (e) {
      debugPrint('[MQTT] ❌ Ошибка подключения: $e');
      rethrow;
    }
  }
}
