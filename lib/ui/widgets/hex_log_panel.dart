import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/locale_provider.dart';
import '../../models/log_entry.dart';
import '../../providers/emulator_provider.dart';
import '../theme/windows_theme.dart';
import 'win_panel.dart';

class HexLogPanel extends ConsumerWidget {
  const HexLogPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(emulatorProvider).logEntries;
    final strings = ref.watch(stringsProvider);

    return WinPanel(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.terminal, size: 18, color: WindowsTheme.accent),
                const SizedBox(width: 8),
                Text(
                  strings.hexLogEvents,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  strings.entriesCount(entries.length),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(strings.noBytesYet))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[entries.length - 1 - index];
                      return _LogTile(entry: entry);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.kind) {
      LogEntryKind.rawHex => const Color(0xFF5C5C5C),
      LogEntryKind.parsedText => const Color(0xFF0F7B0F),
      LogEntryKind.command => const Color(0xFF5C2D91),
      LogEntryKind.event => const Color(0xFF00666B),
      LogEntryKind.error => const Color(0xFFC42B1C),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '[${entry.formattedTime}] ',
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: WindowsTheme.textSecondary,
              ),
            ),
            TextSpan(
              text: '${entry.kind.name.toUpperCase()} ',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: entry.message,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
