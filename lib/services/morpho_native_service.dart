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

  /// [pidOptionsXml] should be the fully-built PidOptions XML string
  /// (see BiometricService._buildPidOptionsXml) including the real wadh.
  static Future<Map<String, dynamic>> captureFingerprint({
    required String pidOptionsXml,
  }) async {
    try {
      final result = await _channel.invokeMethod('captureFingerprint', {
        'pidOptionsXml': pidOptionsXml,
      });
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