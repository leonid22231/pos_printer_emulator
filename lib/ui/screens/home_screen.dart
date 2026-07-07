import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_locale.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../l10n/paper_width_provider.dart';
import '../../providers/emulator_provider.dart';
import '../theme/windows_theme.dart';
import '../widgets/connection_panel.dart';
import '../widgets/hex_log_panel.dart';
import '../widgets/receipt_preview.dart';
import '../widgets/win_button.dart';
import '../widgets/paper_width_selector.dart';
import '../widgets/port_settings_dialog.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emulatorProvider);
    final notifier = ref.read(emulatorProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final locale = ref.watch(localeProvider);
    final paperWidth = ref.watch(paperWidthProvider);

    return Scaffold(
      backgroundColor: WindowsTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TitleBar(
            strings: strings,
            locale: locale,
            onLocaleChanged: (value) =>
                ref.read(localeProvider.notifier).setLocale(value),
            onDemo: () => notifier.loadDemoReceipt(),
            onClear: () => notifier.clear(),
            onSaveLogs: state.logEntries.isEmpty
                ? null
                : () async {
                    final path = await notifier.saveLogs();
                    if (context.mounted && path != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(strings.savedTo(path)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1100;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320,
                        child: ConnectionPanel(
                          onOpenSettings: () => _openSettings(context, ref),
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SectionHeader(
                              title: strings.receiptPreview,
                              subtitle: strings.paperWidthHint(paperWidth),
                              trailing: const PaperWidthSelector(),
                            ),
                            Expanded(
                              child: ColoredBox(
                                color: const Color(0xFFECECEC),
                                child: ReceiptPreview(
                                  key: ValueKey(
                                    'receipt-${state.mode.name}-'
                                    '${state.virtualTransport.name}',
                                  ),
                                  document: state.receipt,
                                  paperWidth: paperWidth,
                                  emptyMessage: strings.previewEmptyForMode(
                                    demoMode:
                                        state.mode == ConnectionMode.mock,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 1),
                      const Expanded(flex: 2, child: HexLogPanel()),
                    ],
                  );
                }

                return Column(
                  children: [
                    SizedBox(
                      height: 360,
                      child: ConnectionPanel(
                        onOpenSettings: () => _openSettings(context, ref),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionHeader(
                            title: strings.receiptPreview,
                            subtitle: strings.paperWidthHint(paperWidth),
                            trailing: const PaperWidthSelector(),
                          ),
                          Expanded(
                            child: ReceiptPreview(
                              key: ValueKey(
                                'receipt-${state.mode.name}-'
                                '${state.virtualTransport.name}',
                              ),
                              document: state.receipt,
                              paperWidth: paperWidth,
                              emptyMessage: strings.previewEmptyForMode(
                                demoMode: state.mode == ConnectionMode.mock,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    const Expanded(flex: 2, child: HexLogPanel()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    showPortSettingsDialog(context, ref);
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.strings,
    required this.locale,
    required this.onLocaleChanged,
    required this.onDemo,
    required this.onClear,
    required this.onSaveLogs,
  });

  final AppStrings strings;
  final AppLocale locale;
  final ValueChanged<AppLocale> onLocaleChanged;
  final VoidCallback onDemo;
  final VoidCallback onClear;
  final VoidCallback? onSaveLogs;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: WindowsTheme.titleBar,
        border: Border(bottom: BorderSide(color: WindowsTheme.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.print, size: 18, color: WindowsTheme.accent),
          const SizedBox(width: 8),
          Text(
            strings.appTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageMenu(locale: locale, onChanged: onLocaleChanged),
                  const SizedBox(width: 8),
                  WinToolbarButton(
                    label: strings.demoReceipt,
                    icon: Icons.receipt_long_outlined,
                    tooltip: strings.demoReceiptTooltip,
                    onPressed: onDemo,
                  ),
                  WinToolbarButton(
                    label: strings.clear,
                    icon: Icons.delete_outline,
                    onPressed: onClear,
                  ),
                  const SizedBox(width: 4),
                  WinToolbarButton(
                    label: strings.saveLogs,
                    icon: Icons.save_outlined,
                    onPressed: onSaveLogs,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({
    required this.locale,
    required this.onChanged,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(locale);
    return PopupMenuButton<AppLocale>(
      tooltip: strings.language,
      initialValue: locale,
      onSelected: onChanged,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16),
            const SizedBox(width: 4),
            Text(
              locale == AppLocale.ru ? 'RU' : 'EN',
              style: const TextStyle(fontSize: 13),
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: AppLocale.ru,
          child: Text(strings.russian),
        ),
        PopupMenuItem(
          value: AppLocale.en,
          child: Text(strings.english),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: WindowsTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
