/// WebRTC 관련 에러를 표현하는 예외 클래스
///
/// WebRTC 연결이나 통신 과정에서 발생하는 다양한 오류를 처리하기 위해 사용됩니다.
class WebRTCError implements Exception {
  /// 에러 메시지
  final String message;

  /// 에러 코드 (선택적)
  final String? code;

  /// 상세 오류 정보 (원본 예외 등)
  final dynamic details;

  /// 생성자
  WebRTCError(this.message, {this.code, this.details});

  @override
  String toString() =>
      'WebRTCError: $message${code != null ? ' (code: $code)' : ''}';

  /// 마이크 접근 권한 오류
  factory WebRTCError.microphonePermissionDenied(String code) =>
      WebRTCError('Microphone permission denied', code: code);

  /// 마이크 접근 실패
  factory WebRTCError.microphoneAccessFailed(String code, dynamic details) =>
      WebRTCError('Failed to access microphone', code: code, details: details);

  /// 세션 초기화 실패
  factory WebRTCError.initializationFailed(dynamic details) =>
      WebRTCError('Failed to initialize session', details: details);

  /// WebRTC 연결 실패
  factory WebRTCError.connectionFailed(dynamic details) =>
      WebRTCError('Failed to setup WebRTC connection', details: details);
}
