# Vona App

Vona는 OpenAI의 realtime API를 활용하여 실시간으로 AI와 대화하고, 그 대화를 바탕으로 하루를 정리하는 Flutter 모바일 애플리케이션입니다. 사용자들이 매일 하루를 쉽게 트래킹하고 어제보다 더 나은 오늘을 살 수 있도록 도와줍니다.

## Features

- 실시간 AI 대화 기능을 통한 일상 정리
- 하루 활동 트래킹 및 분석
  <!-- - 개인화된 목표 설정 및 달성 현황 확인 -->
  <!-- - 일별/주별/월별 리포트 생성 -->
- 감정 분석 및 긍정적인 일상 습관 형성 지원

## Screenshots

<div align="center">
  <img src="assets/screenshots/init.png" alt="AI 대화 화면" width="200"/>
  <img src="assets/screenshots/home.png" alt="일일 요약 화면" width="200"/>
  <img src="assets/screenshots/ai_voice.png" alt="목표 추적 화면" width="200"/>
  <img src="assets/screenshots/journals.png" alt="분석 화면" width="200"/>
</div>

## Tech Stack

- Flutter SDK
- Dart language
- OpenAI API (realtime 기능)
- Supabase (인증 및 데이터 저장)
- Provider (상태 관리)
<!-- - Hive (로컬 데이터 저장) -->

## Project Structure

```
lib/
├── main.dart                 # 앱 진입점
├── firebase_options.dart     # Firebase 설정
├── core/                     # 핵심 기능 및 서비스
│   ├── models/               # 데이터 모델
│   ├── services/             # 서비스 레이어
│   ├── supabase/             # Supabase 관련 코드
│   ├── network/              # 네트워크 통신
│   ├── storage/              # 로컬 저장소 관리
│   ├── prompts/              # AI 프롬프트 템플릿
│   ├── theme/                # 앱 테마 설정
│   └── language/             # 다국어 지원
├── pages/                    # 앱 페이지
│   ├── home_page.dart        # 홈 화면
│   ├── auth/                 # 인증 관련 페이지
│   ├── realtime/             # AI 대화 페이지
│   ├── diary/                # 일기 페이지
│   ├── dashboard/            # 대시보드 페이지
│   ├── profile/              # 프로필 페이지
│   └── settings/             # 설정 페이지
├── widgets/                  # 재사용 가능한 UI 컴포넌트
└── utils/                    # 유틸리티 함수
```

## License

이 프로젝트는 독점 라이센스를 따릅니다 - 자세한 내용은 LICENSE 파일을 참조하세요.

## Acknowledgments

- OpenAI API 팀
- Flutter 커뮤니티
- 베타 테스트에 참여해 주신 모든 분들
