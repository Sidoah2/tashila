import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AuthLanguageMenu extends StatelessWidget {
  const AuthLanguageMenu({super.key});

  static const _locales = <Locale>[
    Locale('en'),
    Locale('ar'),
    Locale('fr'),
  ];

  @override
  Widget build(BuildContext context) {
    final active = context.locale.languageCode;
    return PopupMenuButton<Locale>(
      tooltip: 'language'.tr(),
      icon: const Icon(Icons.language),
      onSelected: (locale) async {
        if (locale.languageCode == context.locale.languageCode) return;
        await context.setLocale(locale);
      },
      itemBuilder: (_) {
        return _locales.map((locale) {
          final key = 'lang_${locale.languageCode}';
          final isActive = locale.languageCode == active;
          return PopupMenuItem<Locale>(
            value: locale,
            child: Row(
              children: [
                Expanded(child: Text(key.tr())),
                if (isActive) const Icon(Icons.check, size: 16),
              ],
            ),
          );
        }).toList(growable: false);
      },
    );
  }
}
