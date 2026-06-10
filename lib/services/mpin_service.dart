import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MpinService {
  static const _storage = FlutterSecureStorage();
  static const _mpinKey = 'user_mpin';
  static const _mpinSetKey = 'mpin_is_set';

  // Save MPIN for first time setup
  static Future<void> setMpin(String mpin) async {
    await _storage.write(key: _mpinKey, value: mpin);
    await _storage.write(key: _mpinSetKey, value: 'true');
  }

  // Verify MPIN during login
  static Future<bool> verifyMpin(String mpin) async {
    final savedMpin = await _storage.read(key: _mpinKey);
    return savedMpin == mpin;
  }

  // Check if MPIN is already set
  static Future<bool> isMpinSet() async {
    final isSet = await _storage.read(key: _mpinSetKey);
    return isSet == 'true';
  }

  // Clear MPIN (for logout)
  static Future<void> clearMpin() async {
    await _storage.delete(key: _mpinKey);
    await _storage.delete(key: _mpinSetKey);
  }

  // Change MPIN
  static Future<bool> changeMpin(String oldMpin, String newMpin) async {
    final isValid = await verifyMpin(oldMpin);
    if (isValid) {
      await setMpin(newMpin);
      return true;
    }
    return false;
  }
}
