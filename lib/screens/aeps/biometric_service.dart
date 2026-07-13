import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:network_info_plus/network_info_plus.dart';

class BiometricService {
  static const String _rdServicePath = '/rd/info';
  static const int _scanTimeoutMs = 3000;  // Increased for Morpho
  static const int _captureTimeoutSec = 20;
  static const int _maxRetries = 3;
  
  static String? _cachedBaseUrl;
  static String? _selectedDeviceType;

  static const Map<String, DeviceConfig> _deviceConfigs = {
    'mantra': DeviceConfig(
      name: 'Mantra MFS-110',
      portRange: [11100, 11101, 11102, 11103, 11104],
      defaultPort: 11100,
      supportsHttps: false,
      responseContains: 'Mantra',
    ),
    'morpho': DeviceConfig(
      name: 'Morpho MSO 1300',
      // ✅ Extended port range for Morpho
      portRange: [11100, 11101, 11102, 11103, 11104, 11105, 11106, 11107, 11108, 11109, 11110, 11111, 11112],
      defaultPort: 11101,
      supportsHttps: true,
      responseContains: 'Morpho',
    ),
    'startek': DeviceConfig(
      name: 'Startek FM220',
      portRange: [11100, 11101, 11102, 11103, 11104, 11105],
      defaultPort: 11102,
      supportsHttps: true,
      responseContains: 'Startek',
    ),
  };

  static Future<void> initialize() async {
    _cachedBaseUrl = null;
    print('✅ Biometric Service initialized');
  }

  // ─── DEBUG: Test Morpho Connection ──────────────────────────────

  static Future<Map<String, dynamic>> debugMorphoConnection() async {
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 DEBUG: Testing Morpho RD Service Connection');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    final results = <String, dynamic>{};
    final hosts = ['127.0.0.1', 'localhost'];
    final ports = [11100, 11101, 11102, 11103, 11104, 11105, 11106, 11107, 11108, 11109, 11110];
    
    for (var host in hosts) {
      for (var port in ports) {
        final url = 'https://$host:$port$_rdServicePath';
        try {
          print('📤 Testing: $url');
          
          final client = HttpClient();
          client.badCertificateCallback = (cert, host, port) => true;
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close().timeout(
            Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Timeout'),
          );
          
          if (response.statusCode == 200) {
            final body = await response.transform(utf8.decoder).join();
            results[url] = {
              'status': 'OK',
              'port': port,
              'response': body.substring(0, body.length > 200 ? 200 : body.length),
            };
            print('✅ FOUND: $url');
            print('📄 Response: ${body.substring(0, body.length > 200 ? 200 : body.length)}');
          }
          client.close();
        } catch (e) {
          // Silent fail
          continue;
        }
      }
    }

    if (results.isEmpty) {
      print('❌ No Morpho RD Service found');
      print('');
      print('📌 Troubleshooting:');
      print('   1. Is Morpho MSO1300E3L1RDService running?');
      print('   2. Check system tray for RD Service icon');
      print('   3. Try restarting the service');
      print('   4. Check Windows Firewall');
      print('   5. Try running as Administrator');
    } else {
      print('✅ Found ${results.length} service(s)');
      results.forEach((url, data) {
        print('   📍 $url (Port ${data['port']})');
      });
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    return results;
  }

  static Future<String?> findRdServiceUrl({
    String? deviceType = 'mantra',
    bool forceRediscovery = false,
  }) async {
    // Check cache first
    if (!forceRediscovery && _cachedBaseUrl != null) {
      if (await _isEndpointValid(_cachedBaseUrl!)) {
        print('📱 RD Service: Using cached URL: $_cachedBaseUrl');
        return _cachedBaseUrl;
      } else {
        print('🔄 Cached endpoint invalid, re-discovering...');
        _cachedBaseUrl = null;
      }
    }

    final config = _deviceConfigs[deviceType];
    if (config == null) {
      print('❌ Unknown device type: $deviceType');
      return null;
    }

    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('🔍 RD Service: Scanning for ${config.name}...');
    print('📡 Port range: ${config.portRange}');
    print('📡 HTTPS supported: ${config.supportsHttps}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // For Morpho, try HTTPS first with all hosts
    if (deviceType == 'morpho') {
      // Try the most common Morpho ports first
      final commonPorts = [11101, 11100, 11102, 11103, 11104, 11105];
      final hosts = ['127.0.0.1', 'localhost'];
      
      for (var host in hosts) {
        for (var port in commonPorts) {
          final testUrl = 'https://$host:$port$_rdServicePath';
          
          try {
            print('📤 Testing: $testUrl');
            
            final client = HttpClient();
            client.badCertificateCallback = (cert, host, port) => true;
            final request = await client.getUrl(Uri.parse(testUrl));
            final response = await request.close().timeout(
              Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('Timeout'),
            );

            if (response.statusCode == 200) {
              // Read response to verify it's Morpho
              final body = await response.transform(utf8.decoder).join();
              client.close();
              
              if (body.contains('Morpho') || body.contains('MSO')) {
                _cachedBaseUrl = 'https://$host:$port';
                _selectedDeviceType = deviceType;
                print('✅ MORPHO FOUND: $_cachedBaseUrl');
                print('📄 Response: ${body.substring(0, body.length > 100 ? 100 : body.length)}');
                print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
                return _cachedBaseUrl;
              } else {
                print('⚠️ Found service but not Morpho at: $testUrl');
              }
            }
            client.close();
          } catch (e) {
            continue;
          }
        }
      }
    }

    // Fallback to normal scanning
    final hosts = await _getAllHosts();
    
    // Try HTTPS first if supported
    if (config.supportsHttps) {
      final result = await _scanHosts(
        hosts, 
        config.portRange, 
        useHttps: true,
        responseContains: config.responseContains,
      );
      if (result != null) {
        _cachedBaseUrl = result;
        _selectedDeviceType = deviceType;
        print('✅ BIOMETRIC | DEVICE FOUND (HTTPS) | $_cachedBaseUrl');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        return _cachedBaseUrl;
      }
    }

    // Try HTTP as fallback
    final result = await _scanHosts(
      hosts, 
      config.portRange, 
      useHttps: false,
      responseContains: config.responseContains,
    );
    if (result != null) {
      _cachedBaseUrl = result;
      _selectedDeviceType = deviceType;
      print('✅ BIOMETRIC | DEVICE FOUND (HTTP) | $_cachedBaseUrl');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return _cachedBaseUrl;
    }

    print('❌ RD Service: ${config.name} not found');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    if (deviceType == 'morpho') {
      print('📌 Morpho RD Service Troubleshooting:');
      print('   1. Run debugMorphoConnection() to see what ports are active');
      print('   2. Check if Morpho RD Service is running (system tray)');
      print('   3. Try opening https://127.0.0.1:11101/rd/info in browser');
      print('   4. Accept the certificate warning');
      print('   5. Restart Morpho RD Service');
      print('   6. Check Windows Firewall settings');
    }
    
    return null;
  }

  static Future<String?> _scanHosts(
    List<String> hosts, 
    List<int> ports, 
    {
      required bool useHttps,
      required String responseContains,
    }
  ) async {
    final protocol = useHttps ? 'https' : 'http';
    
    for (var host in hosts) {
      for (var port in ports) {
        final testUrl = '$protocol://$host:$port$_rdServicePath';

        try {
          print('📤 Testing: $testUrl');
          
          final client = _createHttpClient(useHttps);
          final request = http.Request('DEVICEINFO', Uri.parse(testUrl));
          final response = await client.send(request).timeout(
            Duration(milliseconds: _scanTimeoutMs),
            onTimeout: () => throw TimeoutException('Timeout'),
          );

          if (response.statusCode == 200) {
            final responseBody = await response.stream.bytesToString();
            client.close();
            
            if (responseBody.contains(responseContains)) {
              print('✅ Found ${responseContains} at: $testUrl');
              return '$protocol://$host:$port';
            } else {
              print('⚠️ Found service but not ${responseContains} at: $testUrl');
              continue;
            }
          }
          client.close();
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  static Future<bool> checkDevice({String? deviceType = 'mantra'}) async {
    try {
      print('🔍 Checking device: $deviceType');
      
      final baseUrl = await findRdServiceUrl(
        deviceType: deviceType,
        forceRediscovery: true,
      );
      
      if (baseUrl == null) {
        print('❌ Device URL not found');
        
        // If Morpho, run debug
        if (deviceType == 'morpho') {
          await debugMorphoConnection();
        }
        return false;
      }
      
      final isValid = await _isEndpointValid(baseUrl);
      if (!isValid) {
        _cachedBaseUrl = null;
        print('❌ Endpoint not responding');
        return false;
      }
      
      print('✅ Device available and responding at: $baseUrl');
      return true;
    } catch (e) {
      print('❌ BIOMETRIC | CHECK FAILED | $e');
      _cachedBaseUrl = null;
      return false;
    }
  }

  static Future<String> capturePid({
    String clientKey = 'NEOFYN',
    String? wadh,
    String pipe = '1',
    bool skipWadh = false,
    String? deviceType = 'mantra',
  }) async {
    Exception? lastError;
    
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        print('🔄 Capture attempt $attempt of $_maxRetries');

        String baseUrl;
        try {
          baseUrl = await _getBaseUrl(deviceType: deviceType);
        } catch (e) {
          _cachedBaseUrl = null;
          baseUrl = await _getBaseUrl(deviceType: deviceType);
        }

        final actualWadh = skipWadh ? '' : (wadh ?? _getWadhForPipe(pipe));
        final String xml = _buildPidOptionsXml(clientKey, wadh: actualWadh);

        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📤 BIOMETRIC | CAPTURE | $baseUrl/rd/capture');
        print('📡 Device Type: $deviceType');
        print('⏱️ Timeout: $_captureTimeoutSec seconds');

        final client = _createHttpClient(baseUrl.startsWith('https'));
        
        final request = http.Request('CAPTURE', Uri.parse('$baseUrl/rd/capture'));
        request.headers['Content-Type'] = 'text/xml';
        request.headers['Accept'] = 'text/xml';
        request.body = xml;

        final startTime = DateTime.now();
        final streamedResponse = await client.send(request).timeout(
          Duration(seconds: _captureTimeoutSec),
          onTimeout: () {
            print('⏱️ BIOMETRIC | CAPTURE TIMEOUT');
            client.close();
            throw TimeoutException('Capture timeout - device not responding');
          },
        );

        final response = await http.Response.fromStream(streamedResponse);
        client.close();
        final duration = DateTime.now().difference(startTime);

        print('📥 BIOMETRIC | CAPTURE RESPONSE | ${response.statusCode} | ${duration.inMilliseconds}ms');

        if (response.statusCode == 405) {
          print('❌ BIOMETRIC | ERROR 405 | Method Not Allowed');
          _cachedBaseUrl = null;
          throw Exception('Method Not Allowed (405). Verify RD Service is running.');
        }

        if (response.statusCode != 200) {
          print('❌ BIOMETRIC | ERROR | ${response.statusCode}');
          _cachedBaseUrl = null;
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
        lastError = e is Exception ? e : Exception(e.toString());
        print('💥 BIOMETRIC | CAPTURE ERROR (Attempt $attempt) | $e');
        
        if (attempt == _maxRetries) {
          print('❌ All $_maxRetries attempts failed');
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          if (e is TimeoutException) {
            throw Exception('Capture timeout - please ensure the device is connected');
          }
          rethrow;
        }
        
        await Future.delayed(Duration(seconds: attempt * 2));
        _cachedBaseUrl = null;
      }
    }
    
    throw lastError ?? Exception('Unknown error');
  }

  // ─── HELPER METHODS ─────────────────────────────────────────────

  static http.Client _createHttpClient(bool useHttps) {
    if (useHttps) {
      final client = HttpClient();
      client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      return IOClient(client);
    }
    return http.Client();
  }

  static Future<bool> _isEndpointValid(String baseUrl) async {
    try {
      final client = _createHttpClient(baseUrl.startsWith('https'));
      final request = http.Request('DEVICEINFO', Uri.parse('$baseUrl$_rdServicePath'));
      final response = await client.send(request).timeout(
        Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Timeout'),
      );
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<String>> _getAllHosts() async {
    final hosts = <String>[
      '127.0.0.1',
      'localhost',
      '10.0.2.2',
      '10.0.3.2',
    ];
    
    final deviceIp = await _getDeviceIp();
    if (deviceIp != null) {
      hosts.add(deviceIp);
    }
    
    hosts.addAll([
      '192.168.1.100',
      '192.168.1.101',
      '192.168.0.100',
      '192.168.0.101',
      '10.0.0.100',
      '10.0.0.101',
    ]);
    
    return hosts;
  }

  static Future<String?> _getDeviceIp() async {
    try {
      final networkInfo = NetworkInfo();
      final ip = await networkInfo.getWifiIP();
      return ip?.isNotEmpty == true ? ip : null;
    } catch (e) {
      return null;
    }
  }

  static Future<String> _getBaseUrl({String? deviceType}) async {
    if (_cachedBaseUrl != null) return _cachedBaseUrl!;
    final url = await findRdServiceUrl(deviceType: deviceType ?? 'mantra');
    if (url == null) {
      throw Exception('RD Service not reachable. Ensure RD Service app is running.');
    }
    return url;
  }

  static String _getWadhForPipe(String pipe) {
    return 'E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc=';
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

  static void resetDiscovery() {
    print('🔄 BIOMETRIC | RESET | Clearing cached URL');
    _cachedBaseUrl = null;
    _selectedDeviceType = null;
  }

  static String? get cachedBaseUrl => _cachedBaseUrl;
  static String? get selectedDeviceType => _selectedDeviceType;
  static bool get isUsbConnected => true;
}

class DeviceConfig {
  final String name;
  final List<int> portRange;
  final int defaultPort;
  final bool supportsHttps;
  final String responseContains;

  const DeviceConfig({
    required this.name,
    required this.portRange,
    required this.defaultPort,
    this.supportsHttps = false,
    required this.responseContains,
  });
}