// lib/services/permission_service.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {

  // 🔐 Check all required permissions
  static Future<Map<String, bool>> checkAllPermissions() async {
    Map<String, bool> statuses = {};

    if (!Platform.isAndroid) {
      // iOS permissions
      return {
        'camera': true,
        'location': true,
        'storage': true,
        'bluetooth': true,
      };
    }

    // Camera (for MATM/KYC)
    statuses['camera'] = await Permission.camera.isGranted;

    // Location (for AEPS)
    statuses['location'] = await Permission.location.isGranted;

    // Storage - handle differently per Android version
    statuses['storage'] = await _checkStoragePermission();

    // Bluetooth (for MATM device)
    statuses['bluetooth'] = await _checkBluetoothPermission();

    // ❌ REMOVED: Phone permission - NOT NEEDED
    // Your app uses url_launcher which opens the dialer app
    // This doesn't require PHONE permission

    return statuses;
  }

  // 📱 Check storage permission based on Android version
  static Future<bool> _checkStoragePermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // Try manage external storage first (Android 11+)
      if (await Permission.manageExternalStorage.isGranted) {
        return true;
      }

      // Try regular storage (Android 10 and below)
      if (await Permission.storage.isGranted) {
        return true;
      }

      // Try media permissions (Android 13+)
      if (await Permission.photos.isGranted) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 📶 Check Bluetooth permission based on Android version
  static Future<bool> _checkBluetoothPermission() async {
    if (!Platform.isAndroid) return true;

    try {
      // Try new Bluetooth permissions (Android 12+)
      if (await Permission.bluetoothConnect.isGranted) {
        return true;
      }

      // Try old Bluetooth permission (Android 11 and below)
      if (await Permission.bluetooth.isGranted) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 📋 Get list of denied permissions with readable names
  static List<Map<String, String>> getDeniedPermissionsList(Map<String, bool> statuses) {
    List<Map<String, String>> denied = [];

    final permissionNames = {
      'camera': '📷 Camera',
      'location': '📍 Location',
      'storage': '💾 Storage',
      'bluetooth': '📶 Bluetooth',
      // ❌ REMOVED: 'phone': '📞 Phone',
    };

    final permissionDescriptions = {
      'camera': 'Needed for KYC verification and MATM services',
      'location': 'Needed for AEPS transactions and location verification',
      'storage': 'Needed to save receipts and documents',
      'bluetooth': 'Needed to connect MATM devices',
      // ❌ REMOVED: 'phone': 'Needed to call customer support directly',
    };

    statuses.forEach((key, isGranted) {
      if (!isGranted) {
        denied.add({
          'key': key,
          'name': permissionNames[key] ?? key,
          'description': permissionDescriptions[key] ?? 'Required for app functionality',
        });
      }
    });

    return denied;
  }

  // ✅ Request a specific permission
  static Future<bool> requestPermission(String permissionKey) async {
    try {
      Permission permission;

      switch (permissionKey) {
        case 'camera':
          permission = Permission.camera;
          break;
        case 'location':
          permission = Permission.location;
          break;
        case 'storage':
          return await _requestStoragePermission();
        case 'bluetooth':
          return await _requestBluetoothPermission();
      // ❌ REMOVED: case 'phone':
        default:
          return false;
      }

      final status = await permission.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting $permissionKey: $e');
      return false;
    }
  }

  // 💾 Request storage permission smartly
  static Future<bool> _requestStoragePermission() async {
    try {
      // Try manage external storage first (works for Android 11+)
      if (await Permission.manageExternalStorage.isGranted) return true;

      var status = await Permission.manageExternalStorage.request();
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        // Will need to open settings
        return false;
      }

      // Try regular storage (Android 10 and below)
      status = await Permission.storage.request();
      if (status.isGranted) return true;

      // Try media permissions (Android 13+)
      status = await Permission.photos.request();
      return status.isGranted;
    } catch (e) {
      // If manageExternalStorage fails, try regular storage
      try {
        return await Permission.storage.request().then((s) => s.isGranted);
      } catch (e2) {
        return false;
      }
    }
  }

  // 📶 Request Bluetooth permission smartly
  static Future<bool> _requestBluetoothPermission() async {
    try {
      // Try new Bluetooth permissions (Android 12+)
      var status = await Permission.bluetoothConnect.request();
      if (status.isGranted) {
        await Permission.bluetoothScan.request();
        return true;
      }

      // Try old Bluetooth permission (Android 11 and below)
      status = await Permission.bluetooth.request();
      return status.isGranted;
    } catch (e) {
      try {
        return await Permission.bluetooth.request().then((s) => s.isGranted);
      } catch (e2) {
        return false;
      }
    }
  }

  // 🎯 Request ALL permissions sequentially
  static Future<bool> requestAllPermissions() async {
    // ❌ REMOVED 'phone' from this list
    final permissions = ['camera', 'location', 'storage', 'bluetooth'];
    bool allGranted = true;

    for (String perm in permissions) {
      final granted = await requestPermission(perm);
      if (!granted) allGranted = false;
    }

    return allGranted;
  }

  // 🔓 Open app settings
  static Future<void> openSettings() async {
    await openAppSettings();
  }

  // 📊 Check if CRITICAL permissions are granted
  static Future<bool> areCriticalPermissionsGranted() async {
    final statuses = await checkAllPermissions();

    // At minimum, we need storage for basic app usage
    // ❌ REMOVED phone requirement
    return statuses['storage'] == true;
  }

  // 🔄 Check if ALL permissions (including optional) are granted
  static Future<bool> areAllPermissionsGranted() async {
    final statuses = await checkAllPermissions();
    return !statuses.values.contains(false);
  }
}