import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'location_sharing.dart';

/// Tokens stay in Keychain/Keystore. Concurrent 401s share one refresh request.
class Api {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/',
  );
  final Dio dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(seconds: 30),
  ));
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  String? access;
  Future<void>? _refreshing;
  void Function()? onSessionExpired;

  Api() {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (access != null) options.headers['Authorization'] = 'Bearer $access';
        handler.next(options);
      },
      onError: (error, handler) async {
        final options = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            (options.path.startsWith('auth/') &&
                options.path != 'auth/logout/') ||
            options.extra['retried'] == true) {
          handler.next(error);
          return;
        }
        try {
          // A late response may carry an old token after another request refreshed.
          if (options.headers['Authorization'] == 'Bearer $access') {
            _refreshing ??= _refresh();
            try {
              await _refreshing;
            } finally {
              _refreshing = null;
            }
          }
        } catch (refreshError) {
          // A network outage should not destroy a valid stored session.
          if (refreshError is StateError ||
              (refreshError is DioException &&
                  [400, 401].contains(refreshError.response?.statusCode))) {
            await clear();
            onSessionExpired?.call();
          }
          handler.next(error);
          return;
        }
        options.extra['retried'] = true;
        options.headers['Authorization'] = 'Bearer $access';
        if (options.path == 'auth/logout/') {
          options.data = {'refresh': await storage.read(key: 'refresh')};
        }
        // Multipart streams are single-use. Rebuild them before retrying.
        if (options.data is FormData) {
          options.data = (options.data as FormData).clone();
        }
        try {
          handler.resolve(await dio.fetch<dynamic>(options));
        } on DioException catch (retryError) {
          handler.next(retryError);
        }
      },
    ));
  }

  Future<void> restore() async {
    access = await storage.read(key: 'access');
  }

  Future<void> _save(Map<String, dynamic> tokens) async {
    access = tokens['access'] as String;
    await storage.write(key: 'access', value: access);
    if (tokens['refresh'] != null) {
      await storage.write(key: 'refresh', value: tokens['refresh'] as String);
    }
  }

  Future<void> _refresh() async {
    final refresh = await storage.read(key: 'refresh');
    if (refresh == null) throw StateError('Session expired');
    final response = await dio.post<Map<String, dynamic>>('auth/refresh/',
        data: {'refresh': refresh});
    await _save(response.data!);
  }

  Future<void> login(String email, String password) async {
    final result = await dio.post<Map<String, dynamic>>('auth/token/',
        data: {'email': email.trim(), 'password': password});
    await _save(result.data!);
  }

  Future<void> register(String name, String email, String password) async {
    await dio.post<dynamic>('auth/register/', data: {
      'full_name': name.trim(),
      'email': email.trim(),
      'password': password
    });
    await login(email, password);
  }

  Future<void> clear() async {
    access = null;
    await storage.delete(key: 'access');
    await storage.delete(key: 'refresh');
  }

  Future<void> logout() async {
    final refresh = await storage.read(key: 'refresh');
    try {
      if (refresh != null) {
        await dio.post<dynamic>('auth/logout/', data: {'refresh': refresh});
      }
    } finally {
      await clear();
    }
  }

  Future<Map<String, dynamic>> get(String path) async =>
      (await dio.get<Map<String, dynamic>>(path)).data!;
  Future<void> post(String path, [Map<String, dynamic>? data]) async {
    await dio.post<dynamic>(path, data: data);
  }

  Future<void> patch(String path, Map<String, dynamic> data) async {
    await dio.patch<dynamic>(path, data: data);
  }

  Future<void> delete(String path) async {
    await dio.delete<dynamic>(path);
  }

  Future<void> upload(String filePath) async {
    await dio.post<dynamic>('daily/photo/',
        data: FormData.fromMap({
          'photo':
              await MultipartFile.fromFile(filePath, filename: 'moment.jpg'),
        }));
  }

  String photoUrl(String url) => Uri.parse(baseUrl).resolve(url).toString();
  Map<String, String> photoHeaders(String url) {
    // Never send JWT credentials to S3 or another external host.
    return Uri.parse(photoUrl(url)).origin == Uri.parse(baseUrl).origin
        ? {'Authorization': 'Bearer $access'}
        : {};
  }
}

String friendlyError(Object error) {
  if (error is LocationSharingException) return error.message;
  if (error is DioException) {
    if (error.response == null) {
      return 'Could not connect. Check your connection and try again.';
    }
    final data = error.response?.data;
    if (data is Map) {
      return data.entries
          .map((e) =>
              '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}')
          .join('\n');
    }
    if (data is List) return data.join('\n');
    if (error.response!.statusCode! >= 500) {
      return 'Our server is unavailable. Please try again shortly.';
    }
  }
  return 'Something went wrong. Please try again.';
}
