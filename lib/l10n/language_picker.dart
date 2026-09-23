import 'package:flutter/material.dart';
import 'app_language.dart';
import 'language_controller.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: languageController,
      builder: (context, _) {
        final selected = languageController.language;
        return DropdownButtonHideUnderline(
          child: DropdownButton<AppLanguage>(
            value: selected,
            isDense: true,
            icon: const Icon(Icons.language_rounded, size: 18),
            items: supportedLanguages.map((language) => DropdownMenuItem<AppLanguage>(
              value: language,
              child: Text(compact ? language.nativeName : language.nativeName + '  ·  ' + language.name, style: const TextStyle(fontSize: 13)),
            )).toList(),
            onChanged: (language) { if (language != null) languageController.setLanguage(language); },
          ),
        );
      },
    );
  }
}
