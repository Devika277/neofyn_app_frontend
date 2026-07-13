import 'dart:async';
import 'package:flutter/services.dart';

class UsbPermissionHandler {
  static const MethodChannel _channel = MethodChannel('usb_permission');
  
  static StreamController<Map<String, dynamic>> _usbEventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  static Stream<Map<String, dynamic>> get usbEvents => _usbEventController.stream;

  static Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<Map<String, dynamic>?> requestUsbPermission({
    required int vendorId,
    required int productId,
  }) async {
    try {
      final result = await _channel.invokeMethod('requestUsbPermission', {
        'vendorId': vendorId,
        'productId': productId,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('❌ Error requesting USB permission: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>> getConnectedDevices() async {
    try {
      final result = await _channel.invokeMethod('getConnectedDevices');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('❌ Error getting connected devices: $e');
      return {};
    }
  }

  static Future<bool> checkUsbPermission({
    required int vendorId,
    required int productId,
  }) async {
    try {
      final result = await _channel.invokeMethod('checkUsbPermission', {
        'vendorId': vendorId,
        'productId': productId,
      });
      return result ?? false;
    } catch (e) {
      print('❌ Error checking USB permission: $e');
      return false;
    }
  }

  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onUsbEvent') {
      final data = Map<String, dynamic>.from(call.arguments);
      _usbEventController.add(data);
      print('📱 USB Event: $data');
    }
  }

  static void dispose() {
    _usbEventController.close();
  }
}

// USB Vendor IDs
class UsbVendors {
  static const int mantra = 1204; // 0x04B4
  static const int morpho = 2996; // 0x0BB4
  static const int startek = 1155; // 0x0483
}

// USB Product IDs
class UsbProducts {
  // Mantra
  static const int mfs100 = 4096; // 0x1000
  static const int mfs110 = 4352; // 0x1100
  
  // Morpho
  static const int mso1300 = 3073; // 0x0C01
  
  // Startek
  static const int fm220 = 22304; // 0x5720
}