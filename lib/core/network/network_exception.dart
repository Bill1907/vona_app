class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic error;

  NetworkException({
    required this.message,
    this.statusCode,
    this.error,
  });

  @override
  String toString() => 'NetworkException: $message (Status Code: $statusCode)';
}

class NetworkTimeoutException extends NetworkException {
  NetworkTimeoutException()
      : super(
          message: '네트워크 요청 시간이 초과되었습니다.',
          statusCode: 408,
        );
}

class NetworkConnectionException extends NetworkException {
  NetworkConnectionException()
      : super(
          message: '네트워크 연결에 실패했습니다.',
          statusCode: 503,
        );
}

class UnauthorizedException extends NetworkException {
  UnauthorizedException()
      : super(
          message: '인증이 필요합니다.',
          statusCode: 401,
        );
}
