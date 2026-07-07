import 'app_locale.dart';
import '../models/paper_width.dart';

/// Application UI strings (ru / en).
class AppStrings {
  const AppStrings(this.locale);

  final AppLocale locale;

  bool get isRu => locale == AppLocale.ru;

  String get appTitle => _t(en: 'POS Printer Emulator', ru: 'Эмулятор POS-принтера');

  String get demoReceipt =>
      _t(en: 'Demo receipt', ru: 'Тестовый чек');

  String get demoReceiptTooltip => _t(
        en: 'Play a built-in sample receipt without connecting POS software',
        ru: 'Показать встроенный пример чека без подключения кассы',
      );

  String get clear => _t(en: 'Clear', ru: 'Очистить');

  String get saveLogs => _t(en: 'Save logs', ru: 'Сохранить лог');

  String get receiptPreview =>
      _t(en: 'Receipt preview', ru: 'Предпросмотр чека');

  String get paperWidthLabel => _t(en: 'Paper', ru: 'Бумага');

  String paperWidthOption(PaperWidth width) => switch (width) {
        PaperWidth.mm50 => _t(en: '50mm', ru: '50мм'),
        PaperWidth.mm78 => _t(en: '78mm', ru: '78мм'),
        PaperWidth.mm80 => _t(en: '80mm', ru: '80мм'),
      };

  String paperWidthHint(PaperWidth width) => _t(
        en: '${width.normalChars} chars · ${width.dots} dots',
        ru: '${width.normalChars} симв. · ${width.dots} точек',
      );

  String get hexLogEvents =>
      _t(en: 'Hex log & events', ru: 'Hex-лог и события');

  String get emulator => _t(en: 'Emulator', ru: 'Эмулятор');

  String get virtualMode => _t(en: 'Virtual COM', ru: 'Виртуальный COM');

  String get transportCom => _t(en: 'COM', ru: 'COM');

  String get transportTcp => _t(en: 'TCP', ru: 'TCP');

  String get transportLabel =>
      _t(en: 'Connection type', ru: 'Тип подключения');

  String get com0comRequiredForComMode => _t(
        en: 'COM mode requires com0com. Install it or switch to TCP.',
        ru: 'Режим COM требует com0com. Установите драйвер или переключитесь на TCP.',
      );

  String get tcpModeHint => _t(
        en: 'Emulator listens on TCP 127.0.0.1:9100 (RAW/9100).',
        ru: 'Эмулятор слушает TCP 127.0.0.1:9100 (RAW/9100).',
      );

  String get mockMode => _t(en: 'Demo', ru: 'Демо');

  String get com0comInstalled =>
      _t(en: 'com0com installed', ru: 'com0com установлен');

  String get com0comNotInstalled =>
      _t(en: 'com0com not installed', ru: 'com0com не установлен');

  String get com0comInstalling =>
      _t(en: 'Installing com0com…', ru: 'Установка com0com…');

  String get com0comInstallFailed =>
      _t(en: 'com0com install failed', ru: 'Ошибка установки com0com');

  String get installCom0com =>
      _t(en: 'Install com0com', ru: 'Установить com0com');

  String get verifyCom0com =>
      _t(en: 'Verify', ru: 'Проверить');

  String get removeCom0com =>
      _t(en: 'Remove com0com', ru: 'Удалить com0com');

  String get openDownloadPage =>
      _t(en: 'Download page', ru: 'Страница загрузки');

  String get mockModeTitle => _t(en: 'Demo mode', ru: 'Демо-режим');

  String get mockModeSubtitle => _t(
        en: 'Built-in ESC/POS stream, no external connection required.',
        ru: 'Встроенный поток ESC/POS без внешнего подключения.',
      );

  String get serialSettings =>
      _t(en: 'Serial settings', ru: 'Параметры порта');

  String get baudRate => _t(en: 'Baud rate', ru: 'Скорость');

  String get dataBits => _t(en: 'Data bits', ru: 'Биты данных');

  String get parity => _t(en: 'Parity', ru: 'Чётность');

  String get stopBits => _t(en: 'Stop bits', ru: 'Стоп-биты');

  String get flowControl => _t(en: 'Flow control', ru: 'Управление потоком');

  String get bytesReceived =>
      _t(en: 'Bytes received', ru: 'Получено байт');

  String get lastActivity =>
      _t(en: 'Last activity', ru: 'Последняя активность');

  String get startMock => _t(en: 'Start demo', ru: 'Запустить демо');

  String get startVirtualCom =>
      _t(en: 'Start COM', ru: 'Запустить COM');

  String get startTcp => _t(en: 'Start TCP', ru: 'Запустить TCP');

  String startActionLabel({
    required bool demoMode,
    required bool tcpTransport,
  }) {
    if (demoMode) {
      return startMock;
    }
    return tcpTransport ? startTcp : startVirtualCom;
  }

  String get idleDemoHint => _t(
        en: 'Demo mode — press Start demo for a sample receipt',
        ru: 'Демо-режим — нажмите «Запустить демо» для примера чека',
      );

  String get idleVirtualComHint => _t(
        en: 'Virtual COM — press Start COM to create a port pair',
        ru: 'Виртуальный COM — нажмите «Запустить COM» для создания пары портов',
      );

  String get idleVirtualTcpHint => _t(
        en: 'Virtual TCP — press Start TCP to listen on 127.0.0.1:9100',
        ru: 'Виртуальный TCP — нажмите «Запустить TCP» для прослушивания 127.0.0.1:9100',
      );

  String idleStatusHint({
    required bool demoMode,
    required bool tcpTransport,
  }) {
    if (demoMode) {
      return idleDemoHint;
    }
    return tcpTransport ? idleVirtualTcpHint : idleVirtualComHint;
  }

  String get startEmulator =>
      _t(en: 'Start emulator', ru: 'Запустить эмулятор');

  String get stop => _t(en: 'Stop', ru: 'Остановить');

  String get refresh => _t(en: 'Refresh', ru: 'Обновить');

  String get posConnectHere =>
      _t(en: 'Connect POS here', ru: 'Подключайте кассу сюда');

  String get afterStartEmulator =>
      _t(en: 'After starting the emulator', ru: 'После запуска эмулятора');

  String get addressForPos =>
      _t(en: 'POS printer port', ru: 'Порт для кассы');

  String get emulatorListens =>
      _t(en: 'Emulator listens on', ru: 'Слушает эмулятор');

  String get com0comPairHint => _t(
        en: 'A virtual COM pair (com0com) will be created. '
            'POS software uses one port, the emulator the other.',
        ru: 'Будет создана виртуальная пара COM-портов (com0com). '
            'Касса подключается к одному порту, эмулятор — к другому.',
      );

  String get tcpFallbackHint => _t(
        en: 'Without com0com the emulator listens on TCP 127.0.0.1:9100. '
            'Install com0com for a real COM port.',
        ru: 'Без com0com эмулятор слушает TCP 127.0.0.1:9100. '
            'Установите com0com для настоящего COM-порта.',
      );

  String get copy => _t(en: 'Copy', ru: 'Копировать');

  String copied(String value) =>
      _t(en: 'Copied: $value', ru: 'Скопировано: $value');

  String get noBytesYet => _t(
        en: 'No data received yet',
        ru: 'Данные ещё не получены',
      );

  String entriesCount(int count) => _t(
        en: '$count entries',
        ru: '$count записей',
      );

  String savedTo(String path) =>
      _t(en: 'Saved to $path', ru: 'Сохранено: $path');

  String get virtualPortMode =>
      _t(en: 'Virtual port mode', ru: 'Режим виртуального порта');

  String get com0comAutoPair => _t(
        en: 'com0com is installed — a COM pair is created automatically on start.',
        ru: 'com0com установлен — при старте пара COM-портов создаётся автоматически.',
      );

  String get com0comTcpFallbackSettings => _t(
        en: 'com0com not found — TCP 127.0.0.1:9100 is used instead.',
        ru: 'com0com не найден — используется TCP 127.0.0.1:9100.',
      );

  String get applySettings =>
      _t(en: 'Apply', ru: 'Применить');

  String get previewLabel => _t(en: 'Preview', ru: 'Итого');

  String get settingsApplyAfterStop => _t(
        en: 'Stop the emulator to change port settings.',
        ru: 'Остановите эмулятор, чтобы изменить параметры порта.',
      );

  String get portParamsTitle =>
      _t(en: 'Serial port', ru: 'Последовательный порт');

  String get language => _t(en: 'Language', ru: 'Язык');

  String get english => _t(en: 'English', ru: 'English');

  String get russian => _t(en: 'Русский', ru: 'Русский');

  String get previewEmpty => _t(
        en: 'Receipt preview appears when bytes arrive.',
        ru: 'Предпросмотр чека появится после получения данных.',
      );

  String previewEmptyForMode({required bool demoMode}) => demoMode
      ? _t(
          en: 'Demo mode — press Demo receipt or Start demo',
          ru: 'Демо-режим — нажмите «Тестовый чек» или «Запустить демо»',
        )
      : _t(
          en: 'Virtual mode — connect POS and start the emulator',
          ru: 'Виртуальный режим — подключите кассу и запустите эмулятор',
        );

  String get confirmRemoveCom0comTitle =>
      _t(en: 'Remove com0com?', ru: 'Удалить com0com?');

  String get confirmRemoveCom0comBody => _t(
        en: 'Virtual COM pairs will be removed and the com0com driver will be '
            'uninstalled. Administrator permission (UAC) is required.',
        ru: 'Виртуальные COM-пары будут удалены, драйвер com0com будет '
            'деинсталлирован. Потребуется разрешение администратора (UAC).',
      );

  String get cancel => _t(en: 'Cancel', ru: 'Отмена');

  String get remove => _t(en: 'Remove', ru: 'Удалить');

  String portStateLabel(String state) {
    return switch (state.toLowerCase()) {
      'connected' => _t(en: 'CONNECTED', ru: 'ПОДКЛЮЧЕНО'),
      'mock' => _t(en: 'DEMO', ru: 'ДЕМО'),
      'connecting' => _t(en: 'CONNECTING', ru: 'ПОДКЛЮЧЕНИЕ'),
      'error' => _t(en: 'ERROR', ru: 'ОШИБКА'),
      _ => _t(en: 'STOPPED', ru: 'ОСТАНОВЛЕНО'),
    };
  }

  String eventCom0comReady(String version) => _t(
        en: 'com0com $version ready — virtual COM pairs available',
        ru: 'com0com $version готов — доступны виртуальные COM-пары',
      );

  String get eventCom0comMissing => _t(
        en: 'com0com not installed — TCP 127.0.0.1:9100 fallback available',
        ru: 'com0com не установлен — доступен запасной TCP 127.0.0.1:9100',
      );

  String get eventCom0comTcpFallback => _t(
        en: 'com0com unavailable — using TCP 127.0.0.1:9100',
        ru: 'com0com недоступен — используется TCP 127.0.0.1:9100',
      );

  String get eventEmulatorStopped =>
      _t(en: 'Emulator stopped', ru: 'Эмулятор остановлен');

  String get eventBufferCleared =>
      _t(en: 'Buffer cleared', ru: 'Буфер очищен');

  String get eventDemoLoaded => _t(
        en: 'Demo receipt sent to printer',
        ru: 'Тестовый чек отправлен на печать',
      );

  String logsSaved(String path) =>
      _t(en: 'Logs saved: $path', ru: 'Лог сохранён: $path');

  String saveFailed(String error) =>
      _t(en: 'Save failed: $error', ru: 'Ошибка сохранения: $error');

  String _t({required String en, required String ru}) =>
      locale == AppLocale.ru ? ru : en;
}
