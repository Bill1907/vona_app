import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/language/language_service.dart';
import '../../core/language/extensions.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('language')),
      ),
      body: Consumer<LanguageService>(
        builder: (context, languageService, _) {
          return ListView(
            children: [
              // Use system language option
              ListTile(
                title: Text(context.tr('useSystemLanguage')),
                subtitle: Text(context.tr('useSystemLanguageSubtitle')),
                trailing: Switch(
                  value: languageService.isUsingSystemLocale,
                  onChanged: (value) {
                    if (value) {
                      languageService.useSystemLocale();
                    }
                  },
                ),
                onTap: () {
                  languageService.useSystemLocale();
                },
              ),

              const Divider(),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  context.tr('selectLanguage'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),

              // List of available languages
              ...LanguageService.supportedLocales.map((locale) {
                final bool isSelected = !languageService.isUsingSystemLocale &&
                    languageService.locale.languageCode == locale.languageCode;

                // Language name uses the native spelling of each language, so it is not translated
                String languageName = LanguageService.getDisplayName(locale);

                return ListTile(
                  title: Text(languageName),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    languageService.setLocale(locale);
                  },
                );
              }).toList(),
            ],
          );
        },
      ),
    );
  }
}
