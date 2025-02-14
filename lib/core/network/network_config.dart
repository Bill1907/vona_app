import 'package:flutter_dotenv/flutter_dotenv.dart';

class NetworkConfig {
  static String baseUrl = '${dotenv.env['WEB_VIEW_URL']}/api';
  static const int timeoutSeconds = 30;
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
