import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tashila_driver/core/config/api_config.dart';
import 'package:tashila_driver/core/router/app_router.dart';
import 'package:tashila_driver/core/widgets/api_loading_overlay.dart';

const _kAccessToken = 'accessToken';
const _kRefreshToken = 'refreshToken';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: kApiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'bypass-tunnel-reminder': 'true',
          'User-Agent': 'TashilaDriverApp/1.0',
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (options.extra['showOverlay'] == true) {
            final cancelToken = options.cancelToken ?? CancelToken();
            options.cancelToken = cancelToken;
            final ctx = rootNavigatorKey.currentContext;
            if (ctx != null) {
              ApiOverlayManager.show(ctx, cancelToken: cancelToken);
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.extra['showOverlay'] == true) {
            ApiOverlayManager.hide();
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.requestOptions.extra['showOverlay'] == true) {
            ApiOverlayManager.hide();
          }
          if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
            final data = error.response?.data;
            bool isSuspended = false;
            if (data is Map && data['detail'] == 'Account suspended') {
              isSuspended = true;
            } else if (data is String && data.contains('Account suspended')) {
              isSuspended = true;
            }
            if (isSuspended) {
              onAccountSuspended?.call();
            }
          }
          if (error.response?.statusCode == 401) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final opts = error.requestOptions;
              final token = await getAccessToken();
              opts.headers['Authorization'] = 'Bearer $token';
              try {
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {}
            } else {
              onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  VoidCallback? onUnauthorized;
  VoidCallback? onAccountSuspended;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  Completer<bool>? _refreshCompleter;

  Future<String?> getAccessToken() async {
    try {
      final token = await _secureStorage.read(key: _kAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    // Legacy migration from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_kAccessToken);
    if (legacyToken != null && legacyToken.isNotEmpty) {
      try {
        await _secureStorage.write(key: _kAccessToken, value: legacyToken);
        final legacyRefresh = prefs.getString(_kRefreshToken);
        if (legacyRefresh != null && legacyRefresh.isNotEmpty) {
          await _secureStorage.write(key: _kRefreshToken, value: legacyRefresh);
          await prefs.remove(_kRefreshToken);
        }
        await prefs.remove(_kAccessToken);
      } catch (_) {}
      return legacyToken;
    }
    return null;
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    try {
      await _secureStorage.write(key: _kAccessToken, value: accessToken);
      await _secureStorage.write(key: _kRefreshToken, value: refreshToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: _kAccessToken);
      await _secureStorage.delete(key: _kRefreshToken);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  Future<bool> _tryRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }
    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      String? refresh;
      try {
        refresh = await _secureStorage.read(key: _kRefreshToken);
      } catch (_) {}
      if (refresh == null || refresh.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        refresh = prefs.getString(_kRefreshToken);
      }
      if (refresh == null || refresh.isEmpty) {
        completer.complete(false);
        _refreshCompleter = null;
        return false;
      }
      final response = await Dio().post(
        '$kApiBaseUrl/auth/token/refresh',
        data: {'refreshToken': refresh},
      );
      final newAccess = response.data['accessToken'] as String?;
      final newRefresh = response.data['refreshToken'] as String?;
      if (newAccess == null) {
        completer.complete(false);
        _refreshCompleter = null;
        return false;
      }
      await saveTokens(newAccess, newRefresh ?? refresh);
      completer.complete(true);
      _refreshCompleter = null;
      return true;
    } catch (_) {
      completer.complete(false);
      _refreshCompleter = null;
      return false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _dio.get<T>(path, queryParameters: queryParameters);

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
  }) => _dio.post<T>(path, data: data, queryParameters: queryParameters);

  Future<Response<T>> put<T>(String path, {dynamic data}) =>
      _dio.put<T>(path, data: data);

  Future<Response<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) => _dio.delete<T>(path, queryParameters: queryParameters);

  Future<Response<T>> uploadFile<T>(
    String path,
    String fieldName,
    List<int> bytes,
    String filename, {
    String method = 'PUT',
  }) async {
    final ext = filename.split('.').last.toLowerCase();
    final contentTypeStr = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
    final mediaType = MediaType.parse(contentTypeStr);
    final formData = FormData.fromMap({
      fieldName: MultipartFile.fromBytes(
        bytes,
        filename: filename,
        contentType: mediaType,
      ),
    });
    if (method == 'POST') {
      return _dio.post<T>(path, data: formData);
    }
    return _dio.put<T>(path, data: formData);
  }
}
