import 'dart:convert';
import 'package:http/http.dart' as http;

class LoggedHttpClient {
  static int _counter = 0;

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    _counter++;
    final start = DateTime.now();
    print('📤 REQUEST #$_counter | GET | $url');

    try {
      final response = await http.get(url, headers: headers);
      _logDone(response, start);
      return response;
    } catch (e) {
      print('💥 ERROR #$_counter | $url | $e');
      rethrow;
    }
  }

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    _counter++;
    final start = DateTime.now();
    print('📤 REQUEST #$_counter | POST | $url');
    if (body != null) print('📦 ${_mask(body.toString())}');

    try {
      final response = await http.post(url, headers: headers, body: body, encoding: encoding);
      _logDone(response, start);
      return response;
    } catch (e) {
      print('💥 ERROR #$_counter | $url | $e');
      rethrow;
    }
  }
  static Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    _counter++;
    final start = DateTime.now();
    print('📤 REQUEST #$_counter | PATCH | $url');
    if (body != null) print('📦 ${_mask(body.toString())}');

    try {
      final response = await http.patch(url, headers: headers, body: body, encoding: encoding);
      _logDone(response, start);
      return response;
    } catch (e) {
      print('💥 ERROR #$_counter | $url | $e');
      rethrow;
    }
  }
  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    _counter++;
    final start = DateTime.now();
    print('📤 REQUEST #$_counter | PUT | $url');

    try {
      final response = await http.put(url, headers: headers, body: body, encoding: encoding);
      _logDone(response, start);
      return response;
    } catch (e) {
      print('💥 ERROR #$_counter | $url | $e');
      rethrow;
    }
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    _counter++;
    final start = DateTime.now();
    print('📤 REQUEST #$_counter | DELETE | $url');

    try {
      final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
      _logDone(response, start);
      return response;
    } catch (e) {
      print('💥 ERROR #$_counter | $url | $e');
      rethrow;
    }
  }

  static void _logDone(http.Response response, DateTime start) {
    final ms = DateTime.now().difference(start).inMilliseconds;
    final emoji = response.statusCode == 200 || response.statusCode == 201 ? '✅' : '❌';
    final body = response.body.length > 200 ? '${response.body.substring(0, 200)}...' : response.body;
    print('$emoji RESPONSE #$_counter | ${response.statusCode} | ${ms}ms');
    print('📦 $body');
    print('──────────────────────────────────────────');
  }

  static String _mask(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map) {
        data.forEach((k, v) {
          if (['password', 'mpin', 'newPassword', 'currentMpin', 'newMpin'].contains(k)) {
            data[k] = '***';
          }
        });
        return jsonEncode(data);
      }
    } catch (_) {}
    return body;
  }
}