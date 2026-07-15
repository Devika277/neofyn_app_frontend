import 'package:flutter/services.dart';

class MorphoNativeService {
  static const _channel = MethodChannel('com.example.my_app/morpho');

  static Future<Map<String, dynamic>> initialize() async {
    try {
      final result = await _channel.invokeMethod('initialize');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkDevice() async {
    try {
      final result = await _channel.invokeMethod('checkDevice');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'rdServiceInstalled': false};
    }
  }

  static Future<Map<String, dynamic>> captureFingerprint() async {
    try {
      final result = await _channel.invokeMethod('captureFingerprint');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<bool> openRDService() async {
    try {
      return await _channel.invokeMethod('openRDService') == true;
    } catch (e) {
      return false;
    }
  }
}