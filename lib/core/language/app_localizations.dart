import 'package:flutter/material.dart';

/// A simple class to handle text translations
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  /// Helper method to get a localized instance in the widget tree
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(Locale('en', 'US'));
  }

  /// Lookup dictionary for all supported strings
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'Vona App',
      'settings': 'Settings',
      'language': 'Language',
      'useSystemLanguage': 'Use System Language',
      'useSystemLanguageSubtitle': 'Automatically follow device settings',
      'selectLanguage': 'Select Language',
      'english': 'English',
      'korean': '한국어',
      'logout': 'Logout',
      'logoutConfirmation': 'Are you sure you want to logout?',
      'cancel': 'Cancel',
      'account': 'Account',
      'others': 'Others',
      'darkMode': 'Dark Mode',
      'privacyPolicy': 'Privacy Policy',
      'version': 'Version',
      'profile': 'Profile',
      'appVersion': 'App Version',
      'deleteAccount': 'Delete Account',
      'deleteAccountConfirmation':
          'Are you sure you want to delete your account? This action cannot be undone.',
      'delete': 'Delete',
      'user': 'User',
      'noEmail': 'No email',
      'failedToLoadProfile': 'Failed to load profile',
      'resetPassword': 'Reset Password',
      'signInToYourAccount': 'Sign in to your Account',
      'signInWithGoogle': 'Sign in with Google',
      'signInWithApple': 'Sign in with Apple',
      'signInWithEmail': 'Sign in with Email',
      'dontHaveAccount': 'Don\'t have an account?',
      'signUp': 'Sign Up',
      'emailAddress': 'Email Address',
      'password': 'Password',
      'signIn': 'Sign In',
      'forgotPassword': 'Forgot Password?',
      'fillAllFields': 'Please fill in all fields',
      'unexpectedError': 'An unexpected error occurred.',
      'forgotPasswordTitle': 'Forgot Password',
      'enterEmailForReset':
          'Enter your email address and we will send you a link to reset your password.',
      'enterEmail': 'Please enter your email address',
      'sendResetLink': 'Send Reset Link',
      'resetLinkSent': 'Password reset link has been sent to your email.',
      'backToSignIn': 'Back to Sign In',
      'emailVerificationComplete': 'Email Verification Complete',
      'emailVerificationCompleted': 'Email verification has been completed',
      'canUseAllServices': 'You can now use all services.',
      'getStarted': 'Get Started',
      // Sign Up Page
      'passwordsDoNotMatch': 'Passwords do not match',
      'confirmPassword': 'Confirm Password',
      'alreadyHaveAccount': 'Already have an account?',
      // Verify Email Page
      'verifyEmail': 'Verify Email',
      'emailVerificationRequired': 'Email Verification Required',
      'verificationLinkSent':
          'We have sent a verification link to your email.\nPlease check your email and click the link.',
      'returnToLogin': 'Return to Login',

      // Home Page
      'home': 'Home',
      'voice': 'Voice',
      'journals': 'Journals',

      // Dashboard Page
      'dashboard': 'Dashboard',
      'yourProgress': 'Your progress',
      'ofTheMonthlyJournalCompleted': 'Of the monthly journal completed',
      'history': 'History',
      'journalStats': 'Journal Stats',
      'journalsCount': '{count} journals',

      // Calendar
      'mon': 'MON',
      'tue': 'TUE',
      'wed': 'WED',
      'thu': 'THU',
      'fri': 'FRI',
      'sat': 'SAT',
      'sun': 'SUN',

      // Month names
      'january': 'January',
      'february': 'February',
      'march': 'March',
      'april': 'April',
      'may': 'May',
      'june': 'June',
      'july': 'July',
      'august': 'August',
      'september': 'September',
      'october': 'October',
      'november': 'November',
      'december': 'December',

      // Diary / Journal
      'myJournals': 'My Journals',
      'createNewJournal': 'Create New Journal',
      'editJournal': 'Edit Journal',
      'deleteJournal': 'Delete Journal',
      'confirmDeleteJournal': 'Are you sure you want to delete this journal?',
      'journalDeleted': 'Journal deleted successfully',
      'failedToDeleteJournal': 'Failed to delete journal',
      'save': 'Save',
      'date': 'Date',
      'emotion': 'Emotion',
      'title': 'Title',
      'content': 'Content',
      'addImage': 'Add Image',
      'removeImage': 'Remove Image',

      // Realtime Communication
      'voiceChat': 'Voice Chat',
      'startConversation': 'Start a conversation',
      'endConversation': 'End conversation',
      'yourMessage': 'Your message',
      'sendMessage': 'Send message',
      'connecting': 'Connecting...',
      'connected': 'Connected',
      'disconnected': 'Disconnected',
      'reconnecting': 'Reconnecting...',
    },
    'ko': {
      'appName': '보나 앱',
      'settings': '설정',
      'language': '언어',
      'useSystemLanguage': '시스템 언어 사용',
      'useSystemLanguageSubtitle': '기기 설정을 자동으로 따름',
      'selectLanguage': '언어 선택',
      'english': 'English',
      'korean': '한국어',
      'logout': '로그아웃',
      'logoutConfirmation': '정말 로그아웃하시겠습니까?',
      'cancel': '취소',
      'account': '계정',
      'others': '기타',
      'darkMode': '다크 모드',
      'privacyPolicy': '개인정보 처리방침',
      'version': '버전',
      'profile': '프로필',
      'appVersion': '앱 버전',
      'deleteAccount': '계정 삭제',
      'deleteAccountConfirmation': '정말 계정을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.',
      'delete': '삭제',
      'user': '사용자',
      'noEmail': '이메일 없음',
      'failedToLoadProfile': '프로필 불러오기 실패',
      'resetPassword': '비밀번호 재설정',
      'signInToYourAccount': '계정으로 로그인',
      'signInWithGoogle': '구글로 로그인',
      'signInWithApple': '애플로 로그인',
      'signInWithEmail': '이메일로 로그인',
      'dontHaveAccount': '계정이 없으신가요?',
      'signUp': '회원가입',
      'emailAddress': '이메일 주소',
      'password': '비밀번호',
      'signIn': '로그인',
      'forgotPassword': '비밀번호를 잊으셨나요?',
      'fillAllFields': '모든 필드를 입력해주세요',
      'unexpectedError': '예기치 않은 오류가 발생했습니다.',
      'forgotPasswordTitle': '비밀번호를 잊으셨나요?',
      'enterEmailForReset': '이메일 주소를 입력하면 비밀번호를 재설정할 수 있는 링크를 보내드립니다.',
      'enterEmail': '이메일 주소를 입력해주세요',
      'sendResetLink': '비밀번호 재설정 링크 보내기',
      'resetLinkSent': '비밀번호 재설정 링크가 이메일로 전송되었습니다.',
      'backToSignIn': '로그인으로 돌아가기',
      'emailVerificationComplete': '이메일 인증 완료',
      'emailVerificationCompleted': '이메일 인증이 완료되었습니다',
      'canUseAllServices': '이제 모든 서비스를 이용할 수 있습니다',
      'getStarted': '시작하기',
      // 회원가입 페이지
      'passwordsDoNotMatch': '비밀번호가 일치하지 않습니다',
      'confirmPassword': '비밀번호 확인',
      'alreadyHaveAccount': '이미 계정이 있으신가요?',
      // 이메일 인증 페이지
      'verifyEmail': '이메일 인증',
      'emailVerificationRequired': '이메일 인증이 필요합니다',
      'verificationLinkSent': '인증 링크를 이메일로 발송했습니다.\n이메일을 확인하고 링크를 클릭해주세요.',
      'returnToLogin': '로그인으로 돌아가기',

      // 홈 페이지
      'home': '홈',
      'voice': '음성',
      'journals': '일기',

      // 대시보드 페이지
      'dashboard': '대시보드',
      'yourProgress': '진행 상황',
      'ofTheMonthlyJournalCompleted': '월간 일기 완료율',
      'history': '히스토리',
      'journalStats': '일기 통계',
      'journalsCount': '{count}개의 일기',

      // 달력
      'mon': '월',
      'tue': '화',
      'wed': '수',
      'thu': '목',
      'fri': '금',
      'sat': '토',
      'sun': '일',

      // 월 이름
      'january': '1월',
      'february': '2월',
      'march': '3월',
      'april': '4월',
      'may': '5월',
      'june': '6월',
      'july': '7월',
      'august': '8월',
      'september': '9월',
      'october': '10월',
      'november': '11월',
      'december': '12월',

      // 일기/저널
      'myJournals': '내 일기',
      'createNewJournal': '새 일기 작성',
      'editJournal': '일기 수정',
      'deleteJournal': '일기 삭제',
      'confirmDeleteJournal': '이 일기를 삭제하시겠습니까?',
      'journalDeleted': '일기가 성공적으로 삭제되었습니다',
      'failedToDeleteJournal': '일기 삭제에 실패했습니다',
      'save': '저장',
      'date': '날짜',
      'emotion': '감정',
      'title': '제목',
      'content': '내용',
      'addImage': '이미지 추가',
      'removeImage': '이미지 제거',

      // 실시간 통신
      'voiceChat': '음성 채팅',
      'startConversation': '대화 시작하기',
      'endConversation': '대화 종료하기',
      'yourMessage': '메시지 입력',
      'sendMessage': '메시지 보내기',
      'connecting': '연결 중...',
      'connected': '연결됨',
      'disconnected': '연결 끊김',
      'reconnecting': '재연결 중...',
    },
  };

  /// Get a translated string by key
  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }
}

/// Localization Delegate for creating AppLocalizations instances
class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'ko'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return Future.value(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
