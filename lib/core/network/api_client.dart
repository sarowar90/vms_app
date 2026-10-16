import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../error/exceptions.dart';
import '../storage/storage_providers.dart';

final dioProvider = Provider<Dio>((ref) {
  final tokens = ref.watch(tokenStorageProvider);
  final sessionEvents = ref.watch(sessionEventsProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokens.read();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        final isLogin = error.requestOptions.path.endsWith('auth/login');
        if (error.response?.statusCode == 401 && !isLogin) {
          sessionEvents.notifyExpired();
        }
        handler.next(error);
      },
    ),
  );
  return dio;
});

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(dioProvider)));

/// Emits when the server rejects the stored token, so auth can log out.
final sessionEventsProvider = Provider<SessionEvents>((ref) {
  final events = SessionEvents();
  ref.onDispose(events.dispose);
  return events;
});

class SessionEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onExpired => _controller.stream;

  void notifyExpired() => _controller.add(null);

  void dispose() => _controller.close();
}

/// Thin wrapper over Dio for the VMS API envelope
/// `{success, message, data, meta?, errors?}`.
///
/// Returns the `data` field, or throws [ServerException] / [NetworkException].
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map<String, dynamic>) {
        if (body['success'] == false) throw _toServerException(body, response.statusCode);
        return body['data'];
      }
      return body;
    } on DioException catch (e) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          throw const NetworkException();
        default:
          final body = e.response?.data;
          if (body is Map<String, dynamic>) {
            throw _toServerException(body, e.response?.statusCode);
          }
          throw ServerException(e.message ?? 'Unexpected error', statusCode: e.response?.statusCode);
      }
    }
  }

  ServerException _toServerException(Map<String, dynamic> body, int? statusCode) {
    final rawErrors = body['errors'];
    return ServerException(
      body['message']?.toString() ?? 'Unexpected error',
      statusCode: statusCode,
      errors: rawErrors is Map
          ? rawErrors.map(
              (k, v) => MapEntry(
                k.toString(),
                v is List ? v.map((e) => e.toString()).toList() : [v.toString()],
              ),
            )
          : null,
    );
  }
}
