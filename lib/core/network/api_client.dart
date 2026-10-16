import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  /// For paginated endpoints: returns `data` (a list) and `meta`
  /// (`total`, `page`, `per_page`, `last_page`).
  Future<(List<dynamic>, Map<String, dynamic>)> getPaged(String path, {Map<String, dynamic>? query}) async {
    Map<String, dynamic> meta = const {};
    final data = await _send(
      () => _dio.get(path, queryParameters: query),
      onBody: (body) => meta = (body['meta'] as Map<String, dynamic>?) ?? const {},
    );
    return ((data as List?) ?? const [], meta);
  }

  /// A file download. Returns the bytes and the server's file name
  /// (from `Content-Disposition`), if any.
  Future<(Uint8List, String?)> download(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2)),
      );
      final disposition = response.headers.value('content-disposition') ?? '';
      final name = RegExp(r'filename="?([^";]+)"?').firstMatch(disposition)?.group(1);
      return (Uint8List.fromList(response.data ?? const []), name);
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Future<dynamic> post(String path, {Object? data}) => _send(() => _dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) => _send(() => _dio.put(path, data: data));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(
    Future<Response<dynamic>> Function() request, {
    void Function(Map<String, dynamic> body)? onBody,
  }) async {
    try {
      final response = await request();
      final body = response.data;
      if (body is Map<String, dynamic>) {
        if (body['success'] == false) throw _toServerException(body, response.statusCode);
        onBody?.call(body);
        return body['data'];
      }
      return body;
    } on DioException catch (e) {
      throw _fromDio(e);
    }
  }

  Exception _fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkException();
      default:
        var body = e.response?.data;
        // Downloads receive bytes; errors are still JSON.
        if (body is List<int>) {
          try {
            body = jsonDecode(utf8.decode(body));
          } on FormatException {
            body = null;
          }
        }
        if (body is Map<String, dynamic>) return _toServerException(body, e.response?.statusCode);
        return ServerException(e.message ?? 'Unexpected error', statusCode: e.response?.statusCode);
    }
  }

  ServerException _toServerException(Map<String, dynamic> body, int? statusCode) {
    final rawErrors = body['errors'];
    return ServerException(
      body['message']?.toString() ?? 'Unexpected error',
      statusCode: statusCode,
      errors: rawErrors is Map
          ? rawErrors.map(
              (k, v) => MapEntry(k.toString(), v is List ? v.map((e) => e.toString()).toList() : [v.toString()]),
            )
          : null,
    );
  }
}
