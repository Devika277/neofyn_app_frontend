import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

class BiometricService {
  static const int defaultPort = 11100;
  static const List<String> knownHosts = [
    '127.0.0.1',
    'localhost',
    '10.0.2.2',
    '10.0.3.2',
  ];

  static String? _cachedBaseUrl;

  /// Discover RD Service URL with logging
  static Future<String?> findRdServiceUrl() async {
    if (_cachedBaseUrl != null) {
      print('📱 RD Service: Using cached URL: $_cachedBaseUrl');
      return _cachedBaseUrl;
    }

    final deviceIp = await _getDeviceIp();
    final allHosts = [...knownHosts, if (deviceIp != null) deviceIp];

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 RD Service: Scanning for device...');
    print('📡 Hosts to check: $allHosts');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (var host in allHosts) {
      final testUrl = 'http://$host:$defaultPort/rd/info';

      try {
        // ✅ Use LoggedHttpClient for DEVICEINFO (custom method)
        // Since LoggedHttpClient doesn't have custom methods,
        // we log manually for this special case
        print('📤 BIOMETRIC | DEVICEINFO | $testUrl');

        final request = http.Request('DEVICEINFO', Uri.parse(testUrl));
        final response = await request.send().timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw TimeoutException('Timeout'),
        );

        if (response.statusCode == 200) {
          _cachedBaseUrl = 'http://$host:$defaultPort';
          print('✅ BIOMETRIC | DEVICE FOUND | $_cachedBaseUrl');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          return _cachedBaseUrl;
        } else {
          print('⚠️ BIOMETRIC | $host | Status: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ BIOMETRIC | $host | Error: $e');
      }
    }

    print('❌ RD Service: Device not found');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return null;
  }

  /// Check device status with logging
  static Future<bool> checkDevice() async {
    try {
      final baseUrl = await _getBaseUrl();
      print('📱 BIOMETRIC | CHECK | $baseUrl/rd/info');

      final request = http.Request('DEVICEINFO', Uri.parse('$baseUrl/rd/info'));
      final response = await request.send().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Timeout'),
      );

      final isAvailable = response.statusCode == 200;
      print('${isAvailable ? '✅' : '❌'} BIOMETRIC | CHECK | Available: $isAvailable (${response.statusCode})');
      return isAvailable;
    } catch (e) {
      print('❌ BIOMETRIC | CHECK FAILED | $e');
      _cachedBaseUrl = null;
      return false;
    }
  }

  /// Capture fingerprint with logging
  /// Capture fingerprint with logging
  static Future<String> capturePid({
    String clientKey = 'NEOFYN',
    String? wadh,
    String pipe = '1',
    bool skipWadh = false,
  }) async {
    final baseUrl = await _getBaseUrl();

    // Determine if WADH should be included
    final actualWadh = skipWadh ? '' : (wadh ?? _getWadhForPipe(pipe));

    final String xml = _buildPidOptionsXml(clientKey, wadh: actualWadh);

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📤 BIOMETRIC | CAPTURE | $baseUrl/rd/capture');
    print('📦 WADH: ${skipWadh ? "SKIPPED (Not needed for this transaction)" : actualWadh.substring(0, 20)}...');
    print('📦 Body: ${xml.substring(0, 100)}...');
    print('⏱️ Timeout: 15 seconds');

    final request = http.Request('CAPTURE', Uri.parse('$baseUrl/rd/capture'));
    request.headers['Content-Type'] = 'text/xml';
    request.headers['Accept'] = 'text/xml';
    request.body = xml;

    final startTime = DateTime.now();

    try {
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ BIOMETRIC | CAPTURE TIMEOUT');
          throw TimeoutException('Capture timeout - device not responding');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);
      final duration = DateTime.now().difference(startTime);

      print('📥 BIOMETRIC | CAPTURE RESPONSE | ${response.statusCode} | ${duration.inMilliseconds}ms');
      print('📦 Response: ${response.body.substring(0, 200)}...');

      if (response.statusCode == 405) {
        print('❌ BIOMETRIC | ERROR 405 | Method Not Allowed');
        throw Exception('Method Not Allowed (405). Verify RD Service is running.');
      }

      if (response.statusCode != 200) {
        print('❌ BIOMETRIC | ERROR | ${response.statusCode}');
        throw Exception('RD Service error: ${response.statusCode}');
      }

      final pidData = response.body;

      if (_isSuccessResponse(pidData)) {
        print('✅ BIOMETRIC | CAPTURE SUCCESS');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return pidData;
      }

      final errMsg = _extractErrorMessage(pidData);
      print('❌ BIOMETRIC | CAPTURE FAILED | $errMsg');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      throw Exception(errMsg);

    } catch (e) {
      print('💥 BIOMETRIC | CAPTURE ERROR | $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (e is TimeoutException) {
        throw Exception('Capture timeout - please ensure the device is connected');
      }
      rethrow;
    }
  }


  static void resetDiscovery() {
    print('🔄 BIOMETRIC | RESET | Clearing cached URL');
    _cachedBaseUrl = null;
  }

  static String? get cachedBaseUrl => _cachedBaseUrl;

  static Future<String?> _getDeviceIp() async {
    try {
      final networkInfo = NetworkInfo();
      final ip = await networkInfo.getWifiIP();
      final result = ip?.isNotEmpty == true ? ip : null;
      print('📡 BIOMETRIC | Device IP: ${result ?? "Not available"}');
      return result;
    } catch (e) {
      print('❌ BIOMETRIC | IP Error: $e');
      return null;
    }
  }

  static Future<String> _getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final url = await findRdServiceUrl();
    if (url == null) {
      throw Exception('RD Service not reachable. Ensure RD Service app is running.');
    }
    return url;
  }

  static String _buildPidOptionsXml(String clientKey, {String wadh = 'E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc='}) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<PidOptions ver="1.0">
  <Opts fCount="1" fType="2" format="0" pidVer="2.0" timeout="30000" otp="" posh="UNKNOWN" env="P" wadh="$wadh"/>
  <CustOpts>
    <Param name="clientKey" value="$clientKey"/>
  </CustOpts>
</PidOptions>''';
  }
  static bool _isSuccessResponse(String response) {
    return response.contains('errCode="0"') ||
        response.contains("errCode='0'") ||
        response.contains('errCode="10"') ||
        response.contains("errCode='10'");
  }

  static String _extractErrorMessage(String response) {
    RegExp errInfoRegex = RegExp(r'errInfo="([^"]*)"');
    RegExp errCodeRegex = RegExp(r'errCode="([^"]*)"');
    String? errInfo = errInfoRegex.firstMatch(response)?.group(1);
    String? errCode = errCodeRegex.firstMatch(response)?.group(1);
    if (errInfo != null && errInfo.isNotEmpty) return 'Error $errCode: $errInfo';
    if (errCode != null && errCode != '0' && errCode != '10') return 'Capture failed with error code: $errCode';
    return 'Fingerprint capture failed - unknown error';
  }
  // ✅ Add this helper
  static String _getWadhForPipe(String pipe) {
    switch (pipe) {
      case '1':
        return 'E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc=';
      case '2':
        return '18f4CEiXeXcfGXvgWA/blxD+w2pw7hfQPY45JMytkPw=';
      case '3':
        return 'E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc='; // Default
      default:
        return 'E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc=';
    }
  }
}
