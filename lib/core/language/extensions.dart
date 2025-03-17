import 'package:flutter/material.dart';
import 'app_localizations.dart';

/// BuildContext에 확장 기능을 추가하여 다국어 지원을 더 편리하게 사용
extension LocalizationsExtension on BuildContext {
  /// 현재 컨텍스트의 AppLocalizations 인스턴스에 쉽게 접근할 수 있는 게터
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// 번역된 문자열을 직접 가져오는 편의성 메서드
  String tr(String key) => l10n.translate(key);
}
