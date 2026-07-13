// lib/screens/aeps/biometric_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class BiometricService {
  static const String _rdServicePath = '/rd/info';
  static const String _capturePath = '/rd/capture';
  static const int _scanTimeoutMs = 3000;
  static const int _captureTimeoutSec = 25;
  static const int _maxRetries = 2;

  static String? _cachedBaseUrl;
  static String? _cachedProtocol;
  static String? _selectedDeviceType;
  static bool _deviceConnected = true;

  static const Map<String, DeviceConfig> _deviceConfigs = {
    'mantra': DeviceConfig(
      name: 'Mantra MFS-110',
      portRange: [11100, 11101, 11102],
      defaultPort: 11100,
      protocols: ['http'],
      responseContains: 'Mantra',
      compactXml: false,
      skipCustOpts: false,
      infoPaths: ['/rd/info'],
    ),
    'morpho': DeviceConfig(
      name: 'Morpho MSO 1300',
      portRange: [11100, 11101, 11102, 11103],
      defaultPort: 11101,
      protocols: ['http', 'https'],
      responseContains: 'Morpho',
      compactXml: true,
      skipCustOpts: true,
      infoPaths: ['/rd/info', '/getDeviceInfo', '/device/info'],
    ),
    'startek': DeviceConfig(
      name: 'Startek FM220',
      portRange: [11100, 11101, 11102],
      defaultPort: 11100,
      protocols: ['http'],
      responseContains: 'Startek',
      compactXml: false,
      skipCustOpts: false,
      infoPaths: ['/rd/info'],
    ),
  };

  static Future<void> initialize() async {
    _cachedBaseUrl = null;
    _cachedProtocol = null;
    _deviceConnected = true;
    print('✅ Biometric Service initialized');
  }

  // ─── DEBUG: Check what's on each port ────────────────────

  static Future<void> debugPortResponses() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 DEBUG: Scanning all ports for RD Services...');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (final protocol in ['http', 'https']) {
      final client = _createHttpClient(protocol == 'https');
      for (int port in [11100, 11101, 11102, 11103]) {
        for (final path in ['/rd/info', '/getDeviceInfo', '/device/info']) {
          try {
            final uri = Uri.parse('$protocol://127.0.0.1:$port$path');
            final request = http.Request('DEVICEINFO', uri);
            final response = await client.send(request).timeout(Duration(seconds: 3));
            if (response.statusCode == 200) {
              final body = await response.stream.bytesToString();
              print('✅ $protocol://127.0.0.1:$port$path');
              print('📄 Response: ${body.substring(0, body.length > 300 ? 300 : body.length)}');
              print('---');
            }
          } catch (e) {
            // Skip
          }
        }
      }
      client.close();
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  // ─── FIND RD SERVICE URL ─────────────────────────────────

  static Future<String?> findRdServiceUrl({
    String? deviceType = 'mantra',
    bool forceRediscovery = false,
  }) async {
    if (!forceRediscovery && _cachedBaseUrl != null) {
      if (await _isEndpointValid(_cachedBaseUrl!)) {
        print('📱 Using cached: $_cachedBaseUrl');
        return _cachedBaseUrl;
      } else {
        _cachedBaseUrl = null;
        _cachedProtocol = null;
      }
    }

    final config = _deviceConfigs[deviceType];
    if (config == null) {
      print('❌ Unknown device: $deviceType');
      return null;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 Scanning for ${config.name}...');
    print('📡 Protocols: ${config.protocols}');
    print('📡 Ports: ${config.portRange}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Try each protocol in order
    for (final protocol in config.protocols) {
      final result = await _scanPortsForDevice(
        config.portRange,
        protocol: protocol,
        config: config,
      );
      if (result != null) {
        _cachedBaseUrl = result;
        _cachedProtocol = protocol;
        _selectedDeviceType = deviceType;
        print('✅ FOUND ($protocol): $_cachedBaseUrl');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return _cachedBaseUrl;
      }
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('❌ ${config.name} NOT FOUND');
    print('');
    print('📌 Running debug scan...');
    await debugPortResponses();
    print('');
    print('📌 CHECK:');
    print('   1. Is ${config.name} RD Service app open and running?');
    print('   2. Is the scanner connected via USB?');
    print('   3. Try stopping other RD Services (Mantra/Startek)');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    return null;
  }

  static Future<String?> _scanPortsForDevice(
      List<int> ports, {
        required String protocol,
        required DeviceConfig config,
      }) async {
    final hosts = ['127.0.0.1', 'localhost'];

    for (final host in hosts) {
      for (final port in ports) {
        for (final path in config.infoPaths) {
          final testUrl = '$protocol://$host:$port$path';

          try {
            final client = _createHttpClient(protocol == 'https');
            final uri = Uri.parse(testUrl);
            final request = http.Request('DEVICEINFO', uri);

            final response = await client.send(request).timeout(
              Duration(milliseconds: _scanTimeoutMs),
              onTimeout: () {
                client.close();
                throw TimeoutException('timeout');
              },
            );

            if (response.statusCode == 200) {
              final body = await response.stream.bytesToString();
              client.close();

              print('   ✅ Port $port: Responded (${body.length} bytes)');
              print('   📄 First 150 chars: ${body.substring(0, body.length > 150 ? 150 : body.length)}');

              final bodyLower = body.toLowerCase();
              final targetDevice = config.responseContains.toLowerCase();

              // Check if this response is specifically for our target device
              if (bodyLower.contains(targetDevice)) {
                print('   🎯 Confirmed ${config.name}!');
                return '$protocol://$host:$port';
              }

              // Check if this response belongs to a DIFFERENT device
              bool otherDeviceFound = false;
              for (final entry in _deviceConfigs.entries) {
                if (entry.key != _selectedDeviceType && entry.key != config.responseContains.toLowerCase()) {
                  if (bodyLower.contains(entry.value.responseContains.toLowerCase())) {
                    print('   ⚠️ Port $port is ${entry.value.name}, NOT ${config.name}');
                    otherDeviceFound = true;
                    break;
                  }
                }
              }

              // Only match as generic if no other device was identified
              if (!otherDeviceFound) {
                print('   🎯 Generic RD Service - assuming ${config.name}');
                return '$protocol://$host:$port';
              }
            }
            client.close();
          } on TimeoutException {
            // Skip
          } on SocketException {
            // Skip
          } catch (e) {
            // Skip
          }
        }
      }
    }
    return null;
  }

  // ─── CHECK DEVICE ────────────────────────────────────────

  static Future<bool> checkDevice({String? deviceType = 'mantra'}) async {
    try {
      print('🔍 Checking $deviceType...');

      final baseUrl = await findRdServiceUrl(
        deviceType: deviceType,
        forceRediscovery: true,
      );

      if (baseUrl == null) {
        _deviceConnected = false;
        return false;
      }

      _deviceConnected = true;
      print('✅ $deviceType ready at: $baseUrl');
      return true;
    } catch (e) {
      print('❌ Check failed: $e');
      _deviceConnected = false;
      return false;
    }
  }

  // ─── CAPTURE PID ─────────────────────────────────────────

  static Future<String> capturePid({
    String clientKey = 'NEOFYN',
    String? wadh,
    String pipe = '1',
    bool skipWadh = false,
    String? deviceType = 'mantra',
  }) async {
    Exception? lastError;
    final config = _deviceConfigs[deviceType] ?? _deviceConfigs['mantra']!;
    final is2FA = skipWadh;

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('🔄 Attempt $attempt/$_maxRetries');

        String baseUrl = await _getBaseUrl(deviceType: deviceType);

        // Wake up scanner with retries (fix for errCode 720)
        bool deviceReady = false;
        for (int wakeAttempt = 0; wakeAttempt < 3; wakeAttempt++) {
          try {
            final wakeUrl = '$baseUrl${config.infoPaths.first}';
            final client = _createHttpClient(baseUrl.startsWith('https'));
            final request = http.Request('DEVICEINFO', Uri.parse(wakeUrl));
            await client.send(request).timeout(Duration(seconds: 3));
            client.close();
            print('   ✅ Wake call succeeded (attempt ${wakeAttempt + 1})');
            deviceReady = true;
            break;
          } catch (e) {
            print('   ⚠️ Wake attempt ${wakeAttempt + 1} failed: $e');
          }
          print('   ⏳ Waiting for scanner to initialize...');
          await Future.delayed(Duration(seconds: 2));
        }

        if (!deviceReady) {
          print('   ⚠️ Scanner may not be ready, attempting capture anyway...');
        }

        // wadh must be empty for 2FA
        final actualWadh = is2FA ? '' : (wadh ?? '');

        // Build XML
        final String xml = _buildPidOptionsXml(
          clientKey,
          wadh: actualWadh,
          is2FA: is2FA,
          compactXml: config.compactXml,
          skipCustOpts: config.skipCustOpts,
        );

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 CAPTURE → $baseUrl$_capturePath');
        print('📡 Device: ${config.name}');
        print('📡 2FA: $is2FA | wadh="$actualWadh"');
        print('📄 XML: $xml');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        final client = _createHttpClient(baseUrl.startsWith('https'));
        final request = http.Request('CAPTURE', Uri.parse('$baseUrl$_capturePath'));
        request.headers['Content-Type'] = 'text/xml';
        request.body = xml;

        final timeoutSeconds = is2FA ? 35 : 20;
        final streamedResponse = await client.send(request).timeout(
          Duration(seconds: timeoutSeconds),
          onTimeout: () {
            client.close();
            throw TimeoutException('Timeout');
          },
        );

        final response = await http.Response.fromStream(streamedResponse);
        client.close();

        print('📥 Status: ${response.statusCode}');
        print('📄 Response: ${response.body.substring(0, response.body.length > 300 ? 300 : response.body.length)}');

        if (response.statusCode == 200 && _isSuccessResponse(response.body)) {
          print('✅ CAPTURE SUCCESS');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          _deviceConnected = true;
          return response.body;
        }

        final errMsg = _extractErrorMessage(response.body);
        print('❌ Error: $errMsg');
        throw Exception(errMsg);

      } on TimeoutException {
        _cachedBaseUrl = null;
        _deviceConnected = false;
        lastError = Exception('Timeout. Place finger on scanner and try again.');
      } on SocketException {
        _cachedBaseUrl = null;
        _deviceConnected = false;
        lastError = Exception('Connection refused. RD Service stopped?');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('💥 Error: $e');
      }

      if (attempt < _maxRetries) {
        await Future.delayed(Duration(seconds: attempt * 2));
        if (!_deviceConnected) _cachedBaseUrl = null;
      }
    }

    print('❌ All attempts failed');
    throw lastError ?? Exception('Capture failed');
  }

  // ─── BUILD XML ──────────────────────────────────────────

  static String _buildPidOptionsXml(
      String clientKey, {
        String wadh = '',
        bool is2FA = false,
        bool compactXml = false,
        bool skipCustOpts = false,
      }) {
    final timeout = is2FA ? '30000' : '10000';

    if (compactXml) {
      final opts = '<Opts fCount="1" fType="2" iCount="0" pCount="0" '
          'format="0" pidVer="2.0" timeout="$timeout" '
          'posh="UNKNOWN" env="P" wadh="$wadh"/>';

      final custOpts = skipCustOpts
          ? ''
          : '<CustOpts><Param name="clientKey" value="$clientKey"/></CustOpts>';

      return '<PidOptions ver="1.0">$opts$custOpts</PidOptions>';
    } else {
      return '<?xml version="1.0"?>\n'
          '<PidOptions ver="1.0">\n'
          '  <Opts fCount="1" fType="2" format="0" pidVer="2.0" '
          'timeout="$timeout" posh="UNKNOWN" env="P" wadh="$wadh"/>\n'
          '  <CustOpts>\n'
          '    <Param name="clientKey" value="$clientKey"/>\n'
          '  </CustOpts>\n'
          '</PidOptions>';
    }
  }

  // ─── HELPERS ────────────────────────────────────────────

  static http.Client _createHttpClient(bool useHttps) {
    if (useHttps) {
      final httpClient = HttpClient();
      httpClient.badCertificateCallback = (cert, host, port) => true;
      httpClient.connectionTimeout = Duration(seconds: 10);
      return IOClient(httpClient);
    }
    return http.Client();
  }

  static Future<bool> _isEndpointValid(String baseUrl) async {
    try {
      final useHttps = baseUrl.startsWith('https');
      final client = _createHttpClient(useHttps);
      final uri = Uri.parse('$baseUrl$_rdServicePath');
      final request = http.Request('DEVICEINFO', uri);

      final response = await client.send(request).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          client.close();
          throw TimeoutException('Timeout');
        },
      );
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<String> _getBaseUrl({String? deviceType}) async {
    if (_cachedBaseUrl != null) {
      final isValid = await _isEndpointValid(_cachedBaseUrl!);
      if (isValid) return _cachedBaseUrl!;
      _cachedBaseUrl = null;
      _cachedProtocol = null;
    }

    final url = await findRdServiceUrl(
      deviceType: deviceType ?? 'mantra',
      forceRediscovery: true,
    );

    if (url == null) {
      throw Exception('RD Service not found. Start the RD Service app and try again.');
    }
    return url;
  }

  static bool _isSuccessResponse(String response) =>
      response.contains('errCode="0"') || response.contains("errCode='0'");

  static String _extractErrorMessage(String response) {
    final errCode = RegExp(r'errCode="([^"]*)"').firstMatch(response)?.group(1);
    final errInfo = RegExp(r'errInfo="([^"]*)"').firstMatch(response)?.group(1);
    if (errInfo != null && errInfo.isNotEmpty) return 'Error $errCode: $errInfo';
    return 'Capture failed (Code: $errCode)';
  }

  static void resetDiscovery() {
    _cachedBaseUrl = null;
    _cachedProtocol = null;
    _selectedDeviceType = null;
    _deviceConnected = true;
  }

  static String? get cachedBaseUrl => _cachedBaseUrl;
  static String? get cachedProtocol => _cachedProtocol;
  static bool get isDeviceConnected => _deviceConnected;
  static bool get isUsbConnected => _deviceConnected;
}

class DeviceConfig {
  final String name;
  final List<int> portRange;
  final int defaultPort;
  final List<String> protocols;
  final String responseContains;
  final bool compactXml;
  final bool skipCustOpts;
  final List<String> infoPaths;

  const DeviceConfig({
    required this.name,
    required this.portRange,
    required this.defaultPort,
    required this.protocols,
    required this.responseContains,
    this.compactXml = false,
    this.skipCustOpts = false,
    this.infoPaths = const ['/rd/info'],
  });
}