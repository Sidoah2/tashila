import 'package:dio/dio.dart';
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

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccessToken);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccessToken, accessToken);
    await prefs.setString(_kRefreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccessToken);
    await prefs.remove(_kRefreshToken);
  }

  Future<bool> _tryRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString(_kRefreshToken);
      if (refresh == null) return false;
      final response = await Dio().post(
        '$kApiBaseUrl/auth/token/refresh',
        data: {'refreshToken': refresh},
      );
      final newAccess = response.data['accessToken'] as String?;
      final newRefresh = response.data['refreshToken'] as String?;
      if (newAccess == null) return false;
      await prefs.setString(_kAccessToken, newAccess);
      if (newRefresh != null) {
        await prefs.setString(_kRefreshToken, newRefresh);
      }
      return true;
    } catch (_) {
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
