import 'package:flutter/material.dart';
import '../../core/language/extensions.dart';

class EmailVerificationSuccessPage extends StatelessWidget {
  const EmailVerificationSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('emailVerificationComplete')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              Text(
                context.tr('emailVerificationCompleted'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('canUseAllServices'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/home');
                },
                child: Text(context.tr('getStarted')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
