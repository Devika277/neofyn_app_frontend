// lib/core/services/dio_interceptor.dart

import 'package:dio/dio.dart';

class ApiInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('🌐 Request: ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // ✅ FIX: Convert string "true"/"false" to boolean in response data
    if (response.data is Map<String, dynamic>) {
      _convertSuccessField(response.data as Map<String, dynamic>);
    }
    
    // Also check if data is wrapped in a data field
    if (response.data is Map<String, dynamic> && 
        (response.data as Map<String, dynamic>).containsKey('data') &&
        (response.data as Map<String, dynamic>)['data'] is Map<String, dynamic>) {
      _convertSuccessField((response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>);
    }
    
    print('📥 Response: ${response.statusCode}');
    handler.next(response);
  }

  void _convertSuccessField(Map<String, dynamic> data) {
    if (data.containsKey('success')) {
      final successValue = data['success'];
      if (successValue is String) {
        data['success'] = successValue.toLowerCase() == 'true';
        print('🔄 Converted "success" from String "$successValue" to bool ${data['success']}');
      } else if (successValue is int) {
        data['success'] = successValue == 1;
        print('🔄 Converted "success" from int $successValue to bool ${data['success']}');
      }
    }
    
    // Also check for nested data
    if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
      _convertSuccessField(data['data'] as Map<String, dynamic>);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    print('❌ Error: ${err.message}');
    handler.next(err);
  }
}