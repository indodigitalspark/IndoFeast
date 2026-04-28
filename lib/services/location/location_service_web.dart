import 'dart:async';
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'location_service.dart';

Future<GeoPoint?> getCurrentGeoPointImpl() async {
  final geolocation = html.window.navigator.geolocation;
  try {
    final position = await geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 10),
      maximumAge: const Duration(seconds: 5),
    );
    final coords = position.coords;
    if (coords == null) {
      return null;
    }
    final latitude = (coords.latitude ?? 0).toDouble();
    final longitude = (coords.longitude ?? 0).toDouble();
    return (latitude: latitude, longitude: longitude);
  } catch (_) {
    return null;
  }
}
