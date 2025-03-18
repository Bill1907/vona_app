import 'dart:async';
import 'package:flutter/services.dart';

/// 오디오 레벨 변경 콜백 타입
typedef AudioLevelCallback = void Function(double level);

/// 오디오 상태 변경 콜백 타입
typedef AudioStatusCallback = void Function(bool isActive);

/// 오디오 서비스 클래스
///
/// 네이티브 코드와 통신하여 오디오 레벨 분석 및 관리를 담당합니다.
class AudioService {
  // 네이티브 통신 채널
  static const platform = MethodChannel('com.vona.app/audio_analysis');

  // 오디오 분석 타이머
  Timer? _audioAnalysisTimer;

  // 오디오 상태
  double _currentAudioLevel = 0.0;
  bool _isInputActive = false;
  bool _isOutputActive = false;

  // 타이머
  Timer? _inputIndicatorTimer;
  Timer? _outputIndicatorTimer;

  // 콜백 함수들
  AudioLevelCallback? onAudioLevelChanged;
  AudioStatusCallback? onInputStatusChanged;
  AudioStatusCallback? onOutputStatusChanged;

  /// 오디오 레벨 값 반환
  double get audioLevel => _currentAudioLevel;

  /// 입력 활성화 여부
  bool get isInputActive => _isInputActive;

  /// 출력 활성화 여부
  bool get isOutputActive => _isOutputActive;

  /// 오디오 서비스 생성자
  AudioService({
    this.onAudioLevelChanged,
    this.onInputStatusChanged,
    this.onOutputStatusChanged,
  });

  /// 오디오 분석 시작
  Future<void> startAudioAnalysis() async {
    try {
      await platform.invokeMethod('startAudioAnalysis');

      _audioAnalysisTimer =
          Timer.periodic(const Duration(milliseconds: 100), (_) async {
        try {
          final audioLevel = await platform.invokeMethod('getAudioLevel');
          _currentAudioLevel = audioLevel;

          // 활성 임계값 (0.1 이상일 때 활성으로 간주)
          final bool isActive = audioLevel > 0.1;

          // 출력 상태 변경 시 콜백 호출
          if (isActive != _isOutputActive) {
            _isOutputActive = isActive;
            onOutputStatusChanged?.call(isActive);
          }

          // 오디오 레벨 콜백
          onAudioLevelChanged?.call(audioLevel);
        } catch (e) {
          // 오류 무시
        }
      });
    } catch (e) {
      // 기기에서 지원하지 않는 경우 등의 오류 처리
    }
  }

  /// 오디오 분석 중지
  Future<void> stopAudioAnalysis() async {
    _audioAnalysisTimer?.cancel();
    _audioAnalysisTimer = null;

    try {
      await platform.invokeMethod('stopAudioAnalysis');
    } catch (e) {
      // 오류 무시
    }
  }

  /// 입력 상태 설정
  void setInputActive(bool isActive) {
    if (_isInputActive != isActive) {
      _isInputActive = isActive;
      onInputStatusChanged?.call(isActive);

      // 타이머가 있으면 취소
      _inputIndicatorTimer?.cancel();

      // 활성 상태이면 타이머 설정하지 않음
      if (isActive) {
        return;
      }

      // 타이머 시작 (입력이 끝난 후 0.5초 동안 표시)
      _inputIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
        _isInputActive = false;
        onInputStatusChanged?.call(false);
      });
    }
  }

  /// 출력 상태 설정
  void setOutputActive(bool isActive) {
    if (_isOutputActive != isActive) {
      _isOutputActive = isActive;
      onOutputStatusChanged?.call(isActive);

      // 타이머가 있으면 취소
      _outputIndicatorTimer?.cancel();

      // 활성 상태이면 타이머 설정하지 않음
      if (isActive) {
        return;
      }

      // 타이머 시작 (출력이 끝난 후 0.5초 동안 표시)
      _outputIndicatorTimer = Timer(const Duration(milliseconds: 500), () {
        _isOutputActive = false;
        onOutputStatusChanged?.call(false);
      });
    }
  }

  /// 리소스 정리
  void dispose() {
    _inputIndicatorTimer?.cancel();
    _outputIndicatorTimer?.cancel();
    _audioAnalysisTimer?.cancel();

    _inputIndicatorTimer = null;
    _outputIndicatorTimer = null;
    _audioAnalysisTimer = null;

    stopAudioAnalysis();
  }
}
