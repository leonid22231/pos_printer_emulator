import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'app_strings.dart';

const _localeKey = 'app_locale';

class LocaleNotifier extends Notifier<AppLocale> {
  @override
  AppLocale build() {
    Future.microtask(_loadPersisted);
    return AppLocale.en;
  }

  Future<void> _loadPersisted() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey);
    if (code != null) {
      state = AppLocale.fromCode(code);
    }
  }

  Future<void> setLocale(AppLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, AppLocale>(
  LocaleNotifier.new,
);

final stringsProvider = Provider<AppStrings>((ref) {
  return AppStrings(ref.watch(localeProvider));
});
