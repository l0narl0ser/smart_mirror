import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  String get broker => _prefs?.getString('broker') ?? 'localhost';
  int get port => _prefs?.getInt('port') ?? 1883;
  String get topicPrefix => _prefs?.getString('topicPrefix') ?? 'mirror/';
  String get clientId => _prefs?.getString('clientId') ?? 'smart_mirror_ui';
  String? get username => _prefs?.getString('username');
  String? get password => _prefs?.getString('password');

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveSettings({
    required String broker,
    required int port,
    required String topicPrefix,
    required String clientId,
    String? username,
    String? password,
  }) async {
    await _prefs?.setString('broker', broker);
    await _prefs?.setInt('port', port);
    await _prefs?.setString('topicPrefix', topicPrefix);
    await _prefs?.setString('clientId', clientId);
    if (username != null) {
      await _prefs?.setString('username', username);
    }
    if (password != null) {
      await _prefs?.setString('password', password);
    }
  }
}
