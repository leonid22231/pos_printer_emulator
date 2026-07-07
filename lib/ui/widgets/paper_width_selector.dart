import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/locale_provider.dart';
import '../../l10n/paper_width_provider.dart';
import '../../models/paper_width.dart';
import '../theme/windows_theme.dart';

/// 50 / 78 / 80 mm paper width toggle (Garletz-style).
class PaperWidthSelector extends ConsumerWidget {
  const PaperWidthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final width = ref.watch(paperWidthProvider);
    final notifier = ref.read(paperWidthProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          strings.paperWidthLabel,
          style: const TextStyle(
            fontSize: 12,
            color: WindowsTheme.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        for (final option in PaperWidth.values) ...[
          _PaperChip(
            label: strings.paperWidthOption(option),
            selected: width == option,
            onTap: () => notifier.setPaperWidth(option),
          ),
          if (option != PaperWidth.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _PaperChip extends StatelessWidget {
  const _PaperChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WindowsTheme.accent : WindowsTheme.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? WindowsTheme.accent : WindowsTheme.borderStrong,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : WindowsTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
