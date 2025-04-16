import 'package:flutter/services.dart';

class MapboxTokenProvider {
  static const _platform = MethodChannel(
    'com.byuhydroinformaticslab.rivr.mapbox/token',
  );

  static Future<String> getToken() async {
    try {
      final String token = await _platform.invokeMethod('getMapboxToken');
      return token;
    } on PlatformException catch (e) {
      print('Failed to get token: ${e.message}');
      return '';
    }
  }
}
