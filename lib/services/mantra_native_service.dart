import 'package:flutter/services.dart';

/// Mantra native bridge — mirrors MorphoNativeService's structure exactly,
/// talking to MantraPlugin.java over MethodChannel com.example.my_app/mantra
/// instead of Morpho's com.example.my_app/morpho.
class MantraNativeService {
  static const MethodChannel _channel =
      MethodChannel('com.example.my_app/mantra');

  /// Confirms the plugin/RD helper is wired up and attempts an initial
  /// package detection pass. Returns a map with 'success' and 'package'.
  Future<Map<String, dynamic>> initialize() async {
    final result = await _channel.invokeMethod('initialize');
    return Map<String, dynamic>.from(result as Map);
  }

  /// Checks whether the Mantra RD Service is installed AND responds to
  /// ACTION_DEVICE_INFO. Returns a map with:
  ///   rdServiceInstalled (bool), package (String?), ready (bool),
  ///   deviceInfo (String?), rdServiceInfo (String?)
  Future<Map<String, dynamic>> checkDevice() async {
    final result = await _channel.invokeMethod('checkDevice');
    return Map<String, dynamic>.from(result as Map);
  }

  /// Fires ACTION_CAPTURE with the given PidOptions XML (same schema your
  /// existing capturePid() builder already produces for the HTTP path).
  /// Returns a map with:
  ///   success (bool), pidData (String?) on success,
  ///   error (String?) on failure — including the DNC/DNR distinctions
  ///   MantraPlugin surfaces ("Device not connected" / "Device not registered")
  Future<Map<String, dynamic>> captureFingerprint(String pidOptionsXml) async {
    try {
      final result = await _channel.invokeMethod('captureFingerprint', {
        'pidOptionsXml': pidOptionsXml,
      });
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      return {
        'success': false,
        'error': e.message ?? 'Unknown platform error during capture',
      };
    }
  }

  /// Launches the Mantra RD Service app directly — useful for manual
  /// device test/registration checks from within your app's UI.
  Future<bool> openRDService() async {
    final result = await _channel.invokeMethod('openRDService');
    return result == true;
  }
}
