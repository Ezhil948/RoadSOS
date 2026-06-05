import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_endpoints.dart';

/// Finding #16: JWT token stored in FlutterSecureStorage (Android Keystore / iOS Keychain)
/// instead of plaintext Hive box.
/// 
/// Uses QueuedInterceptorsWrapper because FlutterSecureStorage reads are async,
/// and standard InterceptorsWrapper doesn't support async onRequest.
const _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

/// Helper to store token securely after login
Future<void> saveAccessToken(String token) async {
  await _secureStorage.write(key: 'access_token', value: token);
}

/// Helper to clear token on logout
Future<void> clearAccessToken() async {
  await _secureStorage.delete(key: 'access_token');
}

/// Helper to read token (used by dispatch_provider for WebSocket URL)
Future<String> getAccessToken() async {
  return await _secureStorage.read(key: 'access_token') ?? '';
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiEndpoints.baseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // QueuedInterceptorsWrapper supports async onRequest (unlike InterceptorsWrapper)
  dio.interceptors.add(QueuedInterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _secureStorage.read(key: 'access_token');
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      // Global error handling can be enhanced here
      return handler.next(e);
    }
  ));

  return dio;
});
