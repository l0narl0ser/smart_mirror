import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  String _broker = '192.168.0.212';
  int _port = 1883;
  String _topicPrefix = 'mirror/';
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  Function(String topic, String payload)? onMessageReceived;
  Function(String status)? onConnectionStatusChanged;

  Future<void> connect({
    String? broker,
    int? port,
    String? topicPrefix,
    String? clientId,
    String? username,
    String? password,
  }) async {
    _broker = broker ?? _broker;
    _port = port ?? _port;
    _topicPrefix = topicPrefix ?? _topicPrefix;

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
      await _client!.connect();
    } catch (e) {
      _isConnected = false;
      onConnectionStatusChanged?.call('Connection failed: $e');
      _client!.disconnect();
      rethrow;
    }
  }

  void _onConnected() {
    _isConnected = true;
      onConnectionStatusChanged?.call('Connected to $_broker:$_port');
    _subscribe();
  }

  void _onDisconnected() {
    _isConnected = false;
    onConnectionStatusChanged?.call('Disconnected');
  }

  void _subscribe() {
    _client!.subscribe('$_topicPrefix#', MqttQos.atMostOnce);
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final recMessage = messages[0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      final topic = messages[0].topic;
      onMessageReceived?.call(topic, payload);
    });
  }

  Future<void> publish(String topic, Map<String, dynamic> payload) async {
    if (!_isConnected || _client == null) {
      throw Exception('Not connected to MQTT broker');
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage('$_topicPrefix$topic', MqttQos.atMostOnce, builder.payload!);
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
}
