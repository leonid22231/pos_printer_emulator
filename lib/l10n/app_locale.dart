enum AppLocale {
  en('en'),
  ru('ru');

  const AppLocale(this.code);

  final String code;

  static AppLocale fromCode(String? code) {
    return AppLocale.values.firstWhere(
      (locale) => locale.code == code,
      orElse: () => AppLocale.en,
    );
  }
}
