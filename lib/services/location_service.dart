import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<LocationData?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LOCATION] ❌ Геолокация отключена');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[LOCATION] ❌ Разрешение на геолокацию отклонено');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[LOCATION] ❌ Разрешение отклонено навсегда');
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      String? city;
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          city = placemarks[0].locality ?? placemarks[0].administrativeArea ?? '';
        }
      } catch (e) {
        debugPrint('[LOCATION] ⚠️ Ошибка геокодирования: $e');
      }

      debugPrint('[LOCATION] ✅ Получена локация: ${position.latitude}, ${position.longitude}, city=$city');
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        city: city,
      );
    } catch (e) {
      debugPrint('[LOCATION] ❌ Ошибка получения локации: $e');
      return null;
    }
  }
}

class LocationData {
  final double latitude;
  final double longitude;
  final String? city;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.city,
  });
}
