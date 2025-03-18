import 'package:flutter/material.dart';

/// 연결 상태 표시 위젯
///
/// WebRTC 연결 및 초기화 과정에서의 상태를 시각적으로 보여줍니다.
class ConnectionStatusWidget extends StatelessWidget {
  /// 현재 상태 텍스트
  final String status;

  /// 생성자
  const ConnectionStatusWidget({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3A70EF)),
            ),
            const SizedBox(height: 32),
            Text(
              status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Please wait a moment...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[400],
                  ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStepIndicator(
                  context,
                  'Mic',
                  Icons.mic,
                  status.contains('microphone') || status.contains('Mic'),
                  status.contains('AI') ||
                      status.contains('voice') ||
                      status.contains('Ready'),
                ),
                _buildStepConnector(
                  status.contains('AI') ||
                      status.contains('voice') ||
                      status.contains('Ready'),
                ),
                _buildStepIndicator(
                  context,
                  'AI Model',
                  Icons.psychology,
                  status.contains('AI'),
                  status.contains('voice') || status.contains('Ready'),
                ),
                _buildStepConnector(
                  status.contains('voice') || status.contains('Ready'),
                ),
                _buildStepIndicator(
                  context,
                  'Voice Chat',
                  Icons.chat,
                  status.contains('voice') || status.contains('Ready'),
                  status.contains('Ready'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 단계 표시 아이콘 빌드
  Widget _buildStepIndicator(
    BuildContext context,
    String label,
    IconData icon,
    bool isActive,
    bool isComplete,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isComplete
                ? Color.fromRGBO(76, 175, 80, 0.2)
                : isActive
                    ? Color.fromRGBO(33, 150, 243, 0.2)
                    : Color.fromRGBO(158, 158, 158, 0.1),
            border: Border.all(
              color: isComplete
                  ? Colors.green
                  : isActive
                      ? Colors.blue
                      : Colors.grey,
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: isComplete
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: isComplete
                ? Colors.green
                : isActive
                    ? Colors.blue
                    : Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 단계 연결선 빌드
  Widget _buildStepConnector(bool isActive) {
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isActive ? Colors.green : Color.fromRGBO(158, 158, 158, 0.3),
    );
  }
}
