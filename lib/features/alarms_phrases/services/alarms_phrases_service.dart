import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_model.dart';
import '../models/phrase_model.dart';

class AlarmsPhrasesService {
  static final AlarmsPhrasesService _instance = AlarmsPhrasesService._internal();
  factory AlarmsPhrasesService() => _instance;
  AlarmsPhrasesService._internal();

  static const String _alarmsKey = 'alarms';
  static const String _phrasesKey = 'phrases';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<AlarmModel>> loadAlarms() async {
    final String? jsonString = _prefs?.getString(_alarmsKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => AlarmModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveAlarms(List<AlarmModel> alarms) async {
    final jsonString = jsonEncode(alarms.map((a) => a.toJson()).toList());
    await _prefs?.setString(_alarmsKey, jsonString);
  }

  Future<List<PhraseModel>> loadPhrases() async {
    final String? jsonString = _prefs?.getString(_phrasesKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => PhraseModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> savePhrases(List<PhraseModel> phrases) async {
    final jsonString = jsonEncode(phrases.map((p) => p.toJson()).toList());
    await _prefs?.setString(_phrasesKey, jsonString);
  }
}
