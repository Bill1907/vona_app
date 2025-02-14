import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_config.dart';
import 'network_exception.dart';

class HttpService {
  static final HttpService instance = HttpService._init();
  final http.Client _client;

  HttpService._init() : _client = http.Client();

  Map<String, String> _getHeaders([Map<String, String>? additionalHeaders]) {
    final headers = Map<String, String>.from(NetworkConfig.defaultHeaders);
    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }
    return headers;
  }

  String _buildUrl(String endpoint) {
    final baseUrl = NetworkConfig.baseUrl;
    if (endpoint.startsWith('/')) {
      endpoint = endpoint.substring(1);
    }
    return '$baseUrl/$endpoint';
  }

  Future<T> _handleResponse<T>(
    Future<http.Response> Function() request,
    T Function(dynamic data) onSuccess,
  ) async {
    try {
      final response = await request().timeout(
        Duration(seconds: NetworkConfig.timeoutSeconds),
      );

      final data = json.decode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return onSuccess(data);
      }

      switch (response.statusCode) {
        case 401:
          throw UnauthorizedException();
        case 408:
          throw NetworkTimeoutException();
        default:
          throw NetworkException(
            message: data['message'] ?? '알 수 없는 오류가 발생했습니다.',
            statusCode: response.statusCode,
            error: data,
          );
      }
    } on http.ClientException {
      throw NetworkConnectionException();
    }
  }

  Future<T> get<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) onSuccess,
  }) async {
    final uri = Uri.parse(_buildUrl(endpoint)).replace(
      queryParameters: queryParameters,
    );

    return _handleResponse(
      () => _client.get(uri, headers: _getHeaders(headers)),
      onSuccess,
    );
  }

  Future<T> post<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    required T Function(dynamic data) onSuccess,
  }) async {
    final uri = Uri.parse(_buildUrl(endpoint));

    return _handleResponse(
      () => _client.post(
        uri,
        headers: _getHeaders(headers),
        body: json.encode(body),
      ),
      onSuccess,
    );
  }

  Future<T> put<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    required T Function(dynamic data) onSuccess,
  }) async {
    final uri = Uri.parse(_buildUrl(endpoint));

    return _handleResponse(
      () => _client.put(
        uri,
        headers: _getHeaders(headers),
        body: json.encode(body),
      ),
      onSuccess,
    );
  }

  Future<T> delete<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    required T Function(dynamic data) onSuccess,
  }) async {
    final uri = Uri.parse(_buildUrl(endpoint));

    return _handleResponse(
      () => _client.delete(
        uri,
        headers: _getHeaders(headers),
        body: body != null ? json.encode(body) : null,
      ),
      onSuccess,
    );
  }

  Future<T> patch<T>(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    required T Function(dynamic data) onSuccess,
  }) async {
    final uri = Uri.parse(_buildUrl(endpoint));

    return _handleResponse(
      () => _client.patch(
        uri,
        headers: _getHeaders(headers),
        body: json.encode(body),
      ),
      onSuccess,
    );
  }

  void dispose() {
    _client.close();
  }
}
