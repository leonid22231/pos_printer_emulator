import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/locale_provider.dart';
import '../../models/port_config.dart';
import '../../providers/emulator_provider.dart';
import '../theme/windows_theme.dart';
import 'win_button.dart';

Future<void> showPortSettingsDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => const _PortSettingsDialog(),
  );
}

class _PortSettingsDialog extends ConsumerStatefulWidget {
  const _PortSettingsDialog();

  @override
  ConsumerState<_PortSettingsDialog> createState() =>
      _PortSettingsDialogState();
}

class _PortSettingsDialogState extends ConsumerState<_PortSettingsDialog> {
  PortConfig? _draft;

  PortConfig get _config => _draft ?? ref.read(emulatorProvider).config;

  void _update(PortConfig Function(PortConfig current) update) {
    setState(() => _draft = update(_config));
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final com0com = ref.watch(emulatorProvider).com0comState.isInstalled;
    final isActive = ref.watch(emulatorProvider).status.isActive;

    return Dialog(
      backgroundColor: WindowsTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: WindowsTheme.borderStrong),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_ethernet_outlined,
                    size: 20,
                    color: WindowsTheme.accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.serialSettings,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: strings.cancel,
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                com0com
                    ? strings.com0comAutoPair
                    : strings.com0comTcpFallbackSettings,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A6914).withValues(alpha: 0.08),
                    border: Border.all(
                      color: const Color(0xFF8A6914).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF8A6914),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.settingsApplyAfterStop,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Column(
                  children: [
                    _DialogField(
                      label: strings.baudRate,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('baud-${_config.baudRate}'),
                        initialValue: _config.baudRate,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        items: PortConfig.commonBaudRates
                            .map(
                              (rate) => DropdownMenuItem(
                                value: rate,
                                child: Text('$rate'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _update((c) => c.copyWith(baudRate: value));
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogField(
                            label: strings.dataBits,
                            child: DropdownButtonFormField<int>(
                              initialValue: _config.dataBits,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(value: 7, child: Text('7')),
                                DropdownMenuItem(value: 8, child: Text('8')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _update((c) => c.copyWith(dataBits: value));
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogField(
                            label: strings.parity,
                            child: DropdownButtonFormField<Parity>(
                              initialValue: _config.parity,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: Parity.values
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _update((c) => c.copyWith(parity: value));
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogField(
                            label: strings.stopBits,
                            child: DropdownButtonFormField<StopBits>(
                              initialValue: _config.stopBits,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: StopBits.values
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _update((c) => c.copyWith(stopBits: value));
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DialogField(
                            label: strings.flowControl,
                            child: DropdownButtonFormField<FlowControl>(
                              initialValue: _config.flowControl,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              items: FlowControl.values
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f,
                                      child: Text(f.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  _update(
                                    (c) => c.copyWith(flowControl: value),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: WindowsTheme.background,
                        border: Border.all(color: WindowsTheme.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            strings.previewLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              color: WindowsTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _config.summary,
                            style: const TextStyle(
                              fontFamily: 'Consolas',
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: WinSecondaryButton(
                      label: strings.cancel,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: WinPrimaryButton(
                      label: strings.applySettings,
                      onPressed: () {
                        ref
                            .read(emulatorProvider.notifier)
                            .updateConfig(_config);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogField extends StatelessWidget {
  const _DialogField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: WindowsTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}
