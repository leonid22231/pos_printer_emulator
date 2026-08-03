import 'dart:io';

import 'package:pos_emulator/models/pos_printer_disguise_profile.dart';
import 'package:pos_emulator/services/serial/com0com_installer.dart';

/// Makes the POS-facing side of a com0com pair look like [PosPrinterDisguiseProfile].
///
/// com0com 3.x does not support `setupc change ... DeviceDesc=...` (invalid parameter).
/// FriendlyName is rebuilt from registry `DeviceDesc` via `setupc updatefnames`.
class Com0comPortDisguise {
  Com0comPortDisguise({
    this.profile = PosPrinterDisguiseProfile.kioskDefault,
  });

  final PosPrinterDisguiseProfile profile;

  Future<bool> applyToClientPort({
    required Com0comSetupcLocation setupc,
    required String clientPort,
  }) async {
    if (!Platform.isWindows) {
      return false;
    }

    final bool registryApplied = await _applyRegistryDeviceDesc(clientPort);
    if (!registryApplied) {
      return false;
    }

    await _runSetupc(setupc, <String>['updatefnames']);
    return true;
  }

  /// Parses `setupc list` and returns CNCB* id for [comPort].
  static String? parseClientPortId(String listOutput, String comPort) {
    final String target = _normalizeCom(comPort);
    if (target.isEmpty) {
      return null;
    }

    String? matchedPortId;
    for (final String rawLine in listOutput.split(RegExp(r'\r?\n'))) {
      final String line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      final String upper = line.toUpperCase();
      if (!upper.startsWith('CNCB')) {
        continue;
      }
      final String portId = line.split(RegExp(r'\s+')).first;
      if (_lineReferencesComPort(upper, target)) {
        matchedPortId = portId;
        break;
      }
    }
    return matchedPortId;
  }

  static bool _lineReferencesComPort(String upperLine, String comPort) {
    return upperLine.contains('PORTNAME=$comPort') ||
        upperLine.contains('REALPORTNAME=$comPort') ||
        upperLine.contains('($comPort)') ||
        upperLine.endsWith(comPort);
  }

  static String _normalizeCom(String port) {
    final String trimmed = port.trim().toUpperCase();
    if (trimmed.isEmpty) {
      return '';
    }
    return trimmed.startsWith('COM') ? trimmed : 'COM$trimmed';
  }

  Future<void> _runSetupc(
    Com0comSetupcLocation setupc,
    List<String> args,
  ) async {
    try {
      await Process.run(
        setupc.executable,
        args,
        workingDirectory: setupc.workingDirectory,
        runInShell: true,
      );
    } on Object {
      // Best effort.
    }
  }

  Future<bool> _applyRegistryDeviceDesc(String clientPort) async {
    final String comPort = _normalizeCom(clientPort);
    if (comPort.isEmpty) {
      return false;
    }

    final String deviceDesc = _escapePsSingleQuoted(profile.deviceDesc);
    final String script = '''
\$target = '$comPort'
\$desc = '$deviceDesc'
\$found = \$false
Get-ChildItem 'HKLM:\\SYSTEM\\CurrentControlSet\\Enum\\com0com\\port' -ErrorAction SilentlyContinue |
  ForEach-Object {
    if (\$_.PSChildName -notmatch '^CNCB') { return }
    \$props = Get-ItemProperty -Path \$_.PSPath -ErrorAction SilentlyContinue
    if (\$null -eq \$props) { return }
    \$fn = [string]\$props.FriendlyName
    if ([string]::IsNullOrWhiteSpace(\$fn)) { return }
    if (\$fn -notmatch "\(\$target\)") { return }
    Set-ItemProperty -Path \$_.PSPath -Name DeviceDesc -Value \$desc -ErrorAction Stop
    \$found = \$true
  }
if (-not \$found) { exit 1 }
''';

    final int directExit = await _runPowerShell(script);
    if (directExit == 0) {
      return true;
    }

    return _runPowerShellElevated(script) == 0;
  }

  Future<int> _runPowerShell(String script) async {
    try {
      final ProcessResult result = await Process.run(
        'powershell',
        <String>['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', script],
        runInShell: true,
      );
      return result.exitCode;
    } on Object {
      return 1;
    }
  }

  Future<int> _runPowerShellElevated(String script) async {
    final String escaped = script.replaceAll("'", "''");
    final String command = '''
\$code = @'
$escaped
'@
\$p = Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',\$code -Verb RunAs -PassThru -Wait
if (\$null -eq \$p) { exit 1223 }
exit \$p.ExitCode
''';
    return _runPowerShell(command);
  }

  static String _escapePsSingleQuoted(String value) {
    return value.replaceAll("'", "''");
  }
}
