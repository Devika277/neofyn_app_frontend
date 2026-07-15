import 'dart:io';
import 'dart:convert';

class MorphoSocketService {
  static Socket? _socket;

  /// Connect to Morpho RD Service
  static Future<bool> connectToRDService() async {
    try {
      _socket = await Socket.connect(
        '127.0.0.1',
        11101,
        timeout: Duration(seconds: 5),
      );
      return true;
    } catch (e) {
      print('Morpho connection failed: $e');
      return false;
    }
  }

  /// Check if Morpho device is connected via USB
  static Future<bool> isDeviceConnected() async {
    return await connectToRDService();
  }
  /// Send PID capture command and get response
  static Future<Map<String, dynamic>> capturePid() async {
    try {
      // Connect if not connected
      if (_socket == null) {
        bool connected = await connectToRDService();
        if (!connected) {
          return {
            'success': false,
            'error': 'Cannot connect to Morpho RD Service. Make sure RD Service is running.',
          };
        }
      }

      // XML command for fingerprint capture
      final pidXml = '''<?xml version="1.0"?>
<PidOptions ver="1.0">
    <Opts fCount="1" fType="2" iCount="1" pCount="1" format="0" 
          pidVer="2.0" timeout="10000" posh="UNKNOWN" env="P" />
    <CustOpts>
        <Param name="mantrakey" value="" />
    </CustOpts>
</PidOptions>''';

      // Send command
      _socket!.write(pidXml);
      await _socket!.flush();

      // Wait for response - FIXED LINE
      String response = '';
      await for (var data in _socket!.cast<List<int>>().transform(utf8.decoder)) {
        response += data;
        if (response.contains('</PidData>')) {
          break;
        }
      }

      print('Morpho response received: ${response.length} chars');

      return {
        'success': true,
        'pidData': response,
        'rawXml': response,
      };
    } catch (e) {
      print('Morpho capture error: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }


  /// Close connection
  static void disconnect() {
    try {
      _socket?.destroy();
      _socket = null;
    } catch (e) {
      print('Error closing Morpho socket: $e');
    }
  }
}