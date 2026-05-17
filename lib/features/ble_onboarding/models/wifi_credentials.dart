import 'dart:convert';

class WifiCredentials {
  final String ssid;
  final String password;

  const WifiCredentials({
    required this.ssid,
    required this.password,
  });

  String toJson() {
    return jsonEncode({
      'ssid': ssid,
      'password': password,
    });
  }

  List<int> toBytes() {
    return utf8.encode(toJson());
  }

  @override
  String toString() => toJson();
}
