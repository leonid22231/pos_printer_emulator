import 'dart:io';

import 'package:serial_port_win32/serial_port_win32.dart';

import '../../models/com0com_install_state.dart';
import 'com0com_installer.dart';

/// Creates virtual COM port pairs via [com0com](https://com0com.sourceforge.net/).
class Com0comManager {
  Com0comManager({
    Com0comPaths? paths,
    Com0comInstaller? installer,
  })  : _paths = paths ?? Com0comPaths(),
        _installer = installer ?? Com0comInstaller(paths: paths);

  final Com0comPaths _paths;
  final Com0comInstaller _installer;

  Com0comInstallState _installState = const Com0comInstallState();
  Com0comSetupcLocation? _setupc;
  Com0comPair? _lastPair;

  Com0comInstallState get installState => _installState;

  String get downloadPageUrl => Com0comInstaller.downloadPageUrl;

  Future<Com0comSetupcLocation?> _resolveSetupc() async {
    _setupc ??= await _paths.locateSetupc();
    return _setupc;
  }

  Future<bool> isInstalled() async {
    final state = await checkInstallation();
    return state.isInstalled;
  }

  Future<Com0comInstallState> checkInstallation() async {
    final located = await _resolveSetupc();
    if (located != null && await _paths.verifySetupc(located)) {
      _installState = Com0comInstallState(
        phase: Com0comInstallPhase.installed,
        message: 'com0com ready',
        setupcPath: located.executable,
        downloadUrl: downloadPageUrl,
        version: Com0comInstaller.driverVersion,
      );
      return _installState;
    }

    _installState = const Com0comInstallState(
      phase: Com0comInstallPhase.notInstalled,
      message: 'com0com not installed',
      downloadUrl: Com0comInstaller.downloadPageUrl,
    );
    return _installState;
  }

  Future<Com0comInstallState> install({
    void Function(Com0comInstallState state)? onProgress,
  }) async {
    _setupc = null;
    _installState = await _installer.install(
      onProgress: (state) {
        _installState = state;
        onProgress?.call(state);
      },
    );
    if (_installState.isInstalled) {
      _setupc = await _paths.locateSetupc();
    }
    return _installState;
  }

  Future<Com0comInstallState> uninstall({
    void Function(Com0comInstallState state)? onProgress,
  }) async {
    _setupc = null;
    _lastPair = null;
    _installState = await _installer.uninstall(
      onProgress: (state) {
        _installState = state;
        onProgress?.call(state);
      },
    );
    return _installState;
  }

  Future<void> releasePair(Com0comPair? pair) async {
    if (pair == null) {
      return;
    }
    final setupc = await _resolveSetupc();
    if (setupc == null) {
      return;
    }
    await _paths.removePair(
      setupc,
      emulatorPort: pair.emulatorPort,
      clientPort: pair.clientPort,
    );
    if (_lastPair?.emulatorPort == pair.emulatorPort) {
      _lastPair = null;
    }
  }

  Future<Com0comPair?> createPair({int startAt = 30}) async {
    final setupc = await _resolveSetupc();
    if (setupc == null) {
      return null;
    }

    final existing = SerialPort.getAvailablePorts().toSet();
    for (var n = startAt; n < 250; n += 2) {
      final emulatorPort = 'COM$n';
      final clientPort = 'COM${n + 1}';
      if (existing.contains(emulatorPort) && existing.contains(clientPort)) {
        _lastPair = Com0comPair(
          emulatorPort: emulatorPort,
          clientPort: clientPort,
        );
        return _lastPair;
      }
      if (existing.contains(emulatorPort) || existing.contains(clientPort)) {
        continue;
      }

      final created = await _runInstall(
        setupc,
        emulatorPort: emulatorPort,
        clientPort: clientPort,
      );
      if (created) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        _lastPair = Com0comPair(
          emulatorPort: emulatorPort,
          clientPort: clientPort,
        );
        return _lastPair;
      }
    }
    return null;
  }

  Com0comPair? get lastPair => _lastPair;

  Future<bool> _runInstall(
    Com0comSetupcLocation setupc, {
    required String emulatorPort,
    required String clientPort,
  }) async {
    final result = await Process.run(
      setupc.executable,
      [
        'install',
        'PortName=$emulatorPort',
        'PortName=$clientPort',
      ],
      workingDirectory: setupc.workingDirectory,
      runInShell: true,
    );

    final output = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (result.exitCode != 0 &&
        !output.contains('added') &&
        !output.contains('install') &&
        !output.contains('logged as')) {
      return false;
    }

    final ports = SerialPort.getAvailablePorts();
    return ports.contains(emulatorPort) && ports.contains(clientPort);
  }
}

class Com0comPair {
  const Com0comPair({
    required this.emulatorPort,
    required this.clientPort,
  });

  final String emulatorPort;
  final String clientPort;
}
