import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../models/com0com_install_state.dart';
import '../../models/emulator_endpoint.dart';
import '../../models/port_config.dart';
import '../../models/port_status.dart';
import '../../models/virtual_transport.dart';
import '../../providers/emulator_provider.dart';
import '../../services/serial/com0com_installer.dart';
import '../theme/windows_theme.dart';
import 'win_button.dart';
import 'win_panel.dart';

class ConnectionPanel extends ConsumerWidget {
  const ConnectionPanel({
    super.key,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(emulatorProvider);
    final notifier = ref.read(emulatorProvider.notifier);
    final strings = ref.watch(stringsProvider);
    final config = state.config;
    final status = state.status;
    final endpoint = state.endpoint;

    return WinPanel(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(strings.emulator, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _StatusBanner(
              strings: strings,
              status: status,
              mode: state.mode,
              transport: state.virtualTransport,
            ),
            const SizedBox(height: 16),
            _ModeToggle(
              strings: strings,
              mode: state.mode,
              enabled: !state.isBusy,
              onChanged: notifier.setMode,
            ),
            const SizedBox(height: 16),
            if (state.mode == ConnectionMode.virtual) ...[
              _TransportToggle(
                strings: strings,
                transport: state.virtualTransport,
                enabled: !state.isBusy,
                onChanged: notifier.setVirtualTransport,
              ),
              const SizedBox(height: 12),
              _Com0comStatusCard(
                strings: strings,
                installState: state.com0comState,
                showCom0comActions:
                    state.virtualTransport == VirtualTransport.com,
                onInstall: () => notifier.installCom0com(),
                onRemove: () => _confirmRemoveCom0com(context, ref),
                onOpenDownload: _openDownloadPage,
              ),
              const SizedBox(height: 12),
              _EndpointCard(
                strings: strings,
                endpoint: endpoint,
                transport: state.virtualTransport,
                com0comInstalled: state.com0comState.isInstalled,
                isActive: status.isActive,
              ),
            ] else
              Text(
                strings.mockModeSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            _PortConfigCard(
              strings: strings,
              config: config,
              enabled: !status.isActive,
              onTap: onOpenSettings,
            ),
            const Divider(height: 24),
            _InfoRow(
              label: strings.bytesReceived,
              value: '${status.bytesReceived}',
            ),
            if (status.lastActivity != null)
              _InfoRow(
                label: strings.lastActivity,
                value: status.lastActivity!.toIso8601String(),
              ),
            const SizedBox(height: 16),
            WinPrimaryButton(
              key: ValueKey(
                'start-${state.mode.name}-${state.virtualTransport.name}',
              ),
              label: strings.startActionLabel(
                demoMode: state.mode == ConnectionMode.mock,
                tcpTransport: state.virtualTransport == VirtualTransport.tcp,
              ),
              icon: Icons.play_arrow_rounded,
              onPressed: state.isBusy || status.isActive
                  ? null
                  : () => notifier.openPort(),
            ),
            const SizedBox(height: 8),
            WinSecondaryButton(
              label: strings.stop,
              icon: Icons.stop_rounded,
              onPressed: status.isActive ? () => notifier.closePort() : null,
            ),
            const SizedBox(height: 8),
            WinSecondaryButton(
              label: strings.refresh,
              icon: Icons.refresh_rounded,
              onPressed: () => notifier.refreshEnvironment(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveCom0com(BuildContext context, WidgetRef ref) async {
    final strings = ref.read(stringsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmRemoveCom0comTitle),
        content: Text(strings.confirmRemoveCom0comBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              strings.remove,
              style: const TextStyle(color: Color(0xFFC42B1C)),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(emulatorProvider.notifier).uninstallCom0com();
    }
  }
}

Future<void> _openDownloadPage() async {
  final uri = Uri.parse(Com0comInstaller.downloadPageUrl);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _TransportToggle extends StatelessWidget {
  const _TransportToggle({
    required this.strings,
    required this.transport,
    required this.enabled,
    required this.onChanged,
  });

  final AppStrings strings;
  final VirtualTransport transport;
  final bool enabled;
  final ValueChanged<VirtualTransport> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.transportLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: WindowsTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ModeChip(
                label: strings.transportCom,
                selected: transport == VirtualTransport.com,
                enabled: enabled,
                onTap: () => onChanged(VirtualTransport.com),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ModeChip(
                label: strings.transportTcp,
                selected: transport == VirtualTransport.tcp,
                enabled: enabled,
                onTap: () => onChanged(VirtualTransport.tcp),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.strings,
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final AppStrings strings;
  final ConnectionMode mode;
  final bool enabled;
  final ValueChanged<ConnectionMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ModeChip(
            key: const ValueKey('mode-virtual'),
            label: strings.virtualMode,
            selected: mode == ConnectionMode.virtual,
            enabled: enabled,
            onTap: () => onChanged(ConnectionMode.virtual),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ModeChip(
            key: const ValueKey('mode-mock'),
            label: strings.mockMode,
            selected: mode == ConnectionMode.mock,
            enabled: enabled,
            onTap: () => onChanged(ConnectionMode.mock),
          ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? WindowsTheme.accent : WindowsTheme.surface,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? WindowsTheme.accent : WindowsTheme.borderStrong,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : WindowsTheme.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _Com0comStatusCard extends StatelessWidget {
  const _Com0comStatusCard({
    required this.strings,
    required this.installState,
    required this.showCom0comActions,
    required this.onInstall,
    required this.onRemove,
    required this.onOpenDownload,
  });

  final AppStrings strings;
  final Com0comInstallState installState;
  final bool showCom0comActions;
  final VoidCallback onInstall;
  final VoidCallback onRemove;
  final VoidCallback onOpenDownload;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title) = switch (installState.phase) {
      Com0comInstallPhase.installed => (
          Icons.check_circle_outline,
          const Color(0xFF0F7B0F),
          strings.com0comInstalled,
        ),
      Com0comInstallPhase.failed => (
          Icons.error_outline,
          const Color(0xFFC42B1C),
          strings.com0comInstallFailed,
        ),
      Com0comInstallPhase.uninstalling ||
      Com0comInstallPhase.downloading ||
      Com0comInstallPhase.installing ||
      Com0comInstallPhase.verifying ||
      Com0comInstallPhase.checking => (
          Icons.downloading,
          const Color(0xFF8A6914),
          strings.com0comInstalling,
        ),
      _ => (
          Icons.info_outline,
          WindowsTheme.accent,
          strings.com0comNotInstalled,
        ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
          if (installState.message != null) ...[
            const SizedBox(height: 6),
            Text(
              installState.message!,
              style: const TextStyle(fontSize: 12, color: WindowsTheme.textSecondary),
            ),
          ],
          if (installState.isBusy && installState.progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: installState.progress),
          ],
          if (showCom0comActions) ...[
            const SizedBox(height: 10),
            WinSecondaryButton(
              expanded: true,
              label: installState.isInstalled
                  ? strings.verifyCom0com
                  : strings.installCom0com,
              icon: installState.isInstalled
                  ? Icons.refresh
                  : Icons.download_outlined,
              onPressed: installState.isBusy ? null : onInstall,
            ),
            if (installState.isInstalled) ...[
              const SizedBox(height: 8),
              WinSecondaryButton(
                expanded: true,
                destructive: true,
                label: strings.removeCom0com,
                icon: Icons.delete_outline,
                onPressed: installState.isBusy ? null : onRemove,
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpenDownload,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(strings.openDownloadPage),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({
    required this.strings,
    required this.endpoint,
    required this.transport,
    required this.com0comInstalled,
    required this.isActive,
  });

  final AppStrings strings;
  final EmulatorEndpoint endpoint;
  final VirtualTransport transport;
  final bool com0comInstalled;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: WindowsTheme.accent.withValues(alpha: 0.06),
        border: Border.all(color: WindowsTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isActive ? strings.posConnectHere : strings.afterStartEmulator,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (isActive && endpoint.isConfigured) ...[
            _CopyableRow(
              strings: strings,
              label: strings.addressForPos,
              value: endpoint.clientSide,
            ),
            const SizedBox(height: 4),
            _CopyableRow(
              strings: strings,
              label: strings.emulatorListens,
              value: endpoint.emulatorSide,
            ),
            const SizedBox(height: 8),
            Text(endpoint.instructions, style: Theme.of(context).textTheme.bodySmall),
          ] else
            Text(
              transport == VirtualTransport.tcp
                  ? strings.tcpModeHint
                  : (com0comInstalled
                      ? strings.com0comPairHint
                      : strings.tcpFallbackHint),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

class _CopyableRow extends StatelessWidget {
  const _CopyableRow({
    required this.strings,
    required this.label,
    required this.value,
  });

  final AppStrings strings;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              SelectableText(
                value,
                style: const TextStyle(
                  fontFamily: 'Consolas',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: strings.copy,
          icon: const Icon(Icons.copy, size: 18),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.copied(value)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.strings,
    required this.status,
    required this.mode,
    required this.transport,
  });

  final AppStrings strings;
  final PortStatus status;
  final ConnectionMode mode;
  final VirtualTransport transport;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status.state) {
      PortConnectionState.connected => (
          const Color(0xFF0F7B0F),
          Icons.check_circle_outline,
        ),
      PortConnectionState.mock => (WindowsTheme.accent, Icons.science_outlined),
      PortConnectionState.connecting => (
          const Color(0xFF8A6914),
          Icons.hourglass_top,
        ),
      PortConnectionState.error => (
          const Color(0xFFC42B1C),
          Icons.error_outline,
        ),
      PortConnectionState.disconnected => (
          WindowsTheme.textSecondary,
          Icons.circle_outlined,
        ),
    };

    final statusMessage =
        status.state == PortConnectionState.disconnected && status.error == null
            ? strings.idleStatusHint(
                demoMode: mode == ConnectionMode.mock,
                tcpTransport: transport == VirtualTransport.tcp,
              )
            : status.message;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.portStateLabel(status.state.name),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(statusMessage, style: const TextStyle(fontSize: 13)),
                if (status.error != null)
                  Text(
                    status.error!,
                    style: const TextStyle(
                      color: Color(0xFFC42B1C),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortConfigCard extends StatelessWidget {
  const _PortConfigCard({
    required this.strings,
    required this.config,
    required this.enabled,
    required this.onTap,
  });

  final AppStrings strings;
  final PortConfig config;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? WindowsTheme.surface : WindowsTheme.background,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: enabled ? WindowsTheme.borderStrong : WindowsTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.settings_ethernet_outlined,
                size: 20,
                color: enabled
                    ? WindowsTheme.accent
                    : WindowsTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.portParamsTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ParamChip(label: strings.baudRate, value: '${config.baudRate}'),
                        _ParamChip(
                          label: strings.dataBits,
                          value: '${config.dataBits}',
                        ),
                        _ParamChip(
                          label: strings.parity,
                          value: config.parity.label,
                        ),
                        _ParamChip(
                          label: strings.stopBits,
                          value: config.stopBits.label,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.tune,
                size: 18,
                color: enabled
                    ? WindowsTheme.textPrimary
                    : WindowsTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  const _ParamChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: WindowsTheme.background,
        border: Border.all(color: WindowsTheme.border),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontSize: 11,
                color: WindowsTheme.textSecondary,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: WindowsTheme.textSecondary),
            ),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
