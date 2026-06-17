import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// BiometricService - Handles communication with Mantra RD Service
/// 
/// This service discovers and communicates with the Mantra RD Service
/// for fingerprint capture using the non-standard HTTP protocol.
///
class BiometricService {
  // ─────────────────────────────────────────────────────────────────────────
  // Configuration
  // ─────────────────────────────────────────────────────────────────────────

  /// Default port for Mantra RD Service
  static const int defaultPort = 11100;

  /// Known hosts to check for RD Service
  static const List<String> knownHosts = [
    '127.0.0.1',   // Localhost
    'localhost',   // Localhost alternative
    '10.0.2.2',    // Android emulator localhost
    '10.0.3.2',    // Android emulator alternative
  ];

  /// Cached base URL to avoid repeated discovery
  static String? _cachedBaseUrl;

  // ─────────────────────────────────────────────────────────────────────────
  // Public Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Discover and return the RD Service URL
  /// 
  /// Scans known hosts and returns the first working RD Service URL.
  /// Results are cached for subsequent calls.
  static Future<String?> findRdServiceUrl() async {
    // Return cached if already found
    if (_cachedBaseUrl != null) return _cachedBaseUrl;

    final deviceIp = await _getDeviceIp();
    final allHosts = [...knownHosts, if (deviceIp != null) deviceIp];

    print('🔍 Scanning for RD Service on hosts: $allHosts');

    for (var host in allHosts) {
      final testUrl = 'http://$host:$defaultPort/rd/info';
      print('🔗 Testing: $testUrl');

      try {
        // Use http.Request with custom 'DEVICEINFO' method
        final request = http.Request('DEVICEINFO', Uri.parse(testUrl));
        final response = await request.send().timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            print('⏱️ Timeout checking $host');
            throw TimeoutException('Timeout');
          },
        );

        if (response.statusCode == 200) {
          _cachedBaseUrl = 'http://$host:$defaultPort';
          print('✅ RD Service found at: $_cachedBaseUrl');
          return _cachedBaseUrl;
        } else {
          print('⚠️ $host returned status: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error checking $host: $e');
        // Ignore and try next host
        continue;
      }
    }

    print('❌ RD Service not found on any known host');
    return null;
  }

  /// Check if RD Service is available and responding
  static Future<bool> checkDevice() async {
    try {
      final baseUrl = await _getBaseUrl();
      print('📱 Checking device at: $baseUrl');

      // Use http.Request with custom 'DEVICEINFO' method
      final request = http.Request('DEVICEINFO', Uri.parse('$baseUrl/rd/info'));
      final response = await request.send().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Timeout'),
      );

      final isAvailable = response.statusCode == 200;
      print('📱 Device check result: $isAvailable (status: ${response.statusCode})');
      return isAvailable;
    } catch (e) {
      print('❌ Device check failed: $e');
      // Clear cache to force rediscovery next time
      _cachedBaseUrl = null;
      return false;
    }
  }

  /// Capture fingerprint/PID data from RD Service
  /// 
  /// [clientKey] - Optional client key for authentication
  /// 
  /// Returns the PID XML data on success
  /// Throws Exception on failure with error details
  static Future<String> capturePid({String clientKey = 'NEOFYN',String wadh = '18f4CEiXeXcfGXvgWA/blxD+w2pw7hfQPY45JMytkPw=',  }) async {
    final baseUrl = await _getBaseUrl();
    print('📤 Capturing fingerprint from: $baseUrl');

    // Build the PID options XML
    final String xml = _buildPidOptionsXml(clientKey);

    // ✅ KEY FIX: Use http.Request with custom 'CAPTURE' method
    // DO NOT use http.post() - it sends standard HTTP POST which RD Service rejects
    final request = http.Request('CAPTURE', Uri.parse('$baseUrl/rd/capture'));

    // Set required headers
    request.headers['Content-Type'] = 'text/xml';
    request.headers['Accept'] = 'text/xml';

    // Set the request body
    request.body = xml;

    print('📤 Request body: $xml');

    try {
      // Send the request
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('⏱️ Capture timeout');
          throw TimeoutException('Capture timeout - device not responding');
        },
      );

      // Convert streaming response to regular response
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 405) {
        throw Exception(
          'Method Not Allowed (405). '
          'This usually means the RD Service endpoint does not support this method. '
          'Verify the RD Service is running and properly configured.',
        );
      }

      if (response.statusCode != 200) {
        throw Exception(
          'RD Service error: ${response.statusCode} - ${response.body}',
        );
      }

      final pidData = response.body;

      // Check for success (errCode="0" or errCode="10" for no fingerprint)
      // errCode="10" typically means fingerprint not detected yet, which is still a valid response
      if (_isSuccessResponse(pidData)) {
        print('✅ Fingerprint captured successfully');
        return pidData;
      }

      // Extract error message
      final errMsg = _extractErrorMessage(pidData);
      throw Exception(errMsg);

    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Capture timeout - please ensure the device is connected');
      }
      rethrow;
    }
  }

  /// Reset cached URL (call after device disconnect)
  static void resetDiscovery() {
    print('🔄 Resetting RD Service discovery');
    _cachedBaseUrl = null;
  }

  /// Get the current cached base URL
  static String? get cachedBaseUrl => _cachedBaseUrl;

  // ─────────────────────────────────────────────────────────────────────────
  // Private Helper Methods
  // ─────────────────────────────────────────────────────────────────────────

  /// Get the device's Wi-Fi IP address
  static Future<String?> _getDeviceIp() async {
    try {
      final networkInfo = NetworkInfo();
      final ip = await networkInfo.getWifiIP();
      final result = ip?.isNotEmpty == true ? ip : null;
      print('📡 Device Wi-Fi IP: $result');
      return result;
    } catch (e) {
      print('❌ Failed to get Wi-Fi IP: $e');
      return null;
    }
  }

  /// Get the base URL, discovering if necessary
  static Future<String> _getBaseUrl() async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;

    final url = await findRdServiceUrl();
    if (url == null) {
      throw Exception(
        'RD Service not reachable. '
        'Please ensure:\n'
        '1. Mantra RD Service APK is installed\n'
        '2. RD Service app is running\n'
        '3. Network connectivity is available',
      );
    }
    return url;
  }

  /// Build PID Options XML
  static String _buildPidOptionsXml(String clientKey) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<PidOptions ver="1.0">
  <Opts fCount="1" fType="2" iCount="0" pCount="0" format="0" pidVer="2.0" timeout="10000" env="P"/>
  <CustOpts>
    <Param name="clientKey" value="$clientKey"/>
  </CustOpts>
</PidOptions>''';
  }

  /// Check if response indicates success
  static bool _isSuccessResponse(String response) {
    // errCode="0" = success
    // errCode="10" = no fingerprint found (but still valid response from device)
    return response.contains('errCode="0"') ||
        response.contains("errCode='0'") ||
        response.contains('errCode="10"') ||
        response.contains("errCode='10'");
  }

  /// Extract error message from PID response
  static String _extractErrorMessage(String response) {
    // Try different patterns for error info
    RegExp errInfoRegex = RegExp(r'errInfo="([^"]*)"');
    RegExp errCodeRegex = RegExp(r'errCode="([^"]*)"');

    String? errInfo = errInfoRegex.firstMatch(response)?.group(1);
    String? errCode = errCodeRegex.firstMatch(response)?.group(1);

    if (errInfo != null && errInfo.isNotEmpty) {
      return 'Error $errCode: $errInfo';
    }

    if (errCode != null && errCode != '0' && errCode != '10') {
      return 'Capture failed with error code: $errCode';
    }

    return 'Fingerprint capture failed - unknown error';
  }
}