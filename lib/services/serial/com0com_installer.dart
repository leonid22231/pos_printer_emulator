import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../models/com0com_install_state.dart';

/// Downloads com0com manual install bundle and registers the virtual COM driver.
///
/// Uses the signed manual ZIP (contains `amd64/setupc.exe`) instead of the NSIS
/// setup.exe which often leaves no `setupc.exe` in Program Files.
/// https://github.com/BrickBot/Archive/releases/tag/com0com
class Com0comInstaller {
  Com0comInstaller({Com0comPaths? paths}) : _paths = paths ?? Com0comPaths();

  final Com0comPaths _paths;

  static const downloadPageUrl =
      'https://github.com/BrickBot/Archive/releases/tag/com0com';

  static const manualInstallZipUrl =
      'https://github.com/BrickBot/Archive/releases/download/com0com/com0com-3.0.0.0-Win-x86_x64_ManualInstall-Signed.zip';

  /// Fallback NSIS installer (rarely leaves setupc in Program Files).
  static const signedX64ExeUrl =
      'https://github.com/BrickBot/Archive/releases/download/com0com/com0com-3.0.0.0-Win-x64_Setup-Signed.exe';

  static const downloadMaxAttempts = 3;

  static const downloadRetryDelay = Duration(seconds: 2);

  static const driverVersion = '3.0.0.0';

  Future<Com0comInstallState> checkInstallation() async {
    final located = await _paths.locateSetupc();
    if (located != null) {
      return Com0comInstallState(
        phase: Com0comInstallPhase.installed,
        message: 'com0com $driverVersion ready',
        setupcPath: located.executable,
        downloadUrl: downloadPageUrl,
        version: driverVersion,
      );
    }

    return Com0comInstallState(
      phase: Com0comInstallPhase.notInstalled,
      message: 'com0com not installed',
      downloadUrl: downloadPageUrl,
    );
  }

  Future<Com0comInstallState> install({
    void Function(Com0comInstallState state)? onProgress,
  }) async {
    void emit(Com0comInstallState state) => onProgress?.call(state);

    emit(
      const Com0comInstallState(
        phase: Com0comInstallPhase.checking,
        message: 'Checking com0com...',
        downloadUrl: downloadPageUrl,
      ),
    );

    final existing = await checkInstallation();
    if (existing.isInstalled) {
      emit(existing);
      return existing;
    }

    if (!Platform.isWindows) {
      const failed = Com0comInstallState(
        phase: Com0comInstallPhase.failed,
        message: 'com0com is only supported on Windows',
        downloadUrl: downloadPageUrl,
      );
      emit(failed);
      return failed;
    }

    try {
      emit(
        Com0comInstallState(
          phase: Com0comInstallPhase.downloading,
          message: 'Downloading com0com $driverVersion...',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        ),
      );

      final bundle = await _downloadAndExtractBundle(
        onProgress: (progress) => emit(
          Com0comInstallState(
            phase: Com0comInstallPhase.downloading,
            progress: progress,
            message: 'Downloading com0com $driverVersion...',
            downloadUrl: downloadPageUrl,
            version: driverVersion,
          ),
        ),
        onRetry: (attempt, max) => emit(
          Com0comInstallState(
            phase: Com0comInstallPhase.downloading,
            message:
                'Connection timeout, retrying download ($attempt/$max)...',
            downloadUrl: downloadPageUrl,
            version: driverVersion,
          ),
        ),
      );

      emit(
        Com0comInstallState(
          phase: Com0comInstallPhase.installing,
          message:
              'Installing com0com driver (UAC — allow administrator access)...',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        ),
      );

      final installResult = await _installDriver(bundle);
      if (installResult != 0) {
        final message = installResult == 1223
            ? 'Installation cancelled — UAC prompt was denied'
            : 'Driver install failed (exit code $installResult)';
        final failed = Com0comInstallState(
          phase: Com0comInstallPhase.failed,
          message: message,
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        );
        emit(failed);
        return failed;
      }

      emit(
        const Com0comInstallState(
          phase: Com0comInstallPhase.verifying,
          message: 'Verifying com0com...',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        ),
      );

      final located = await _paths.waitForSetupc(
        timeout: const Duration(seconds: 60),
      );
      if (located == null) {
        const failed = Com0comInstallState(
          phase: Com0comInstallPhase.failed,
          message:
              'setupc.exe extracted but driver did not register. '
              'Try reboot, disable Secure Boot, or install manually from GitHub.',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        );
        emit(failed);
        return failed;
      }

      final success = Com0comInstallState(
        phase: Com0comInstallPhase.installed,
        message: 'com0com $driverVersion installed (${located.executable})',
        setupcPath: located.executable,
        downloadUrl: downloadPageUrl,
        version: driverVersion,
      );
      emit(success);
      return success;
    } catch (e) {
      final failed = Com0comInstallState(
        phase: Com0comInstallPhase.failed,
        message: 'Install failed: $e',
        downloadUrl: downloadPageUrl,
        version: driverVersion,
      );
      emit(failed);
      return failed;
    }
  }

  /// Removes virtual COM pairs and uninstalls the com0com driver (UAC).
  Future<Com0comInstallState> uninstall({
    void Function(Com0comInstallState state)? onProgress,
  }) async {
    void emit(Com0comInstallState state) => onProgress?.call(state);

    emit(
      const Com0comInstallState(
        phase: Com0comInstallPhase.uninstalling,
        message: 'Removing com0com...',
        downloadUrl: downloadPageUrl,
      ),
    );

    if (!Platform.isWindows) {
      const failed = Com0comInstallState(
        phase: Com0comInstallPhase.failed,
        message: 'com0com is only supported on Windows',
        downloadUrl: downloadPageUrl,
      );
      emit(failed);
      return failed;
    }

    final located = await _paths.locateSetupc();
    if (located == null) {
      await _deleteLocalBundle();
      const success = Com0comInstallState(
        phase: Com0comInstallPhase.notInstalled,
        message: 'com0com was not installed',
        downloadUrl: downloadPageUrl,
      );
      emit(success);
      return success;
    }

    try {
      await _paths.removeAllPortPairs(located);

      emit(
        Com0comInstallState(
          phase: Com0comInstallPhase.uninstalling,
          message: 'Uninstalling com0com driver (UAC)...',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        ),
      );

      final exitCode = await _uninstallDriver(located);
      if (exitCode != 0 && exitCode != 1223) {
        final failed = Com0comInstallState(
          phase: Com0comInstallPhase.failed,
          message: exitCode == 1223
              ? 'Uninstall cancelled — UAC prompt was denied'
              : 'Driver uninstall failed (exit code $exitCode)',
          downloadUrl: downloadPageUrl,
          version: driverVersion,
        );
        emit(failed);
        return failed;
      }

      await _deleteLocalBundle();

      final success = Com0comInstallState(
        phase: Com0comInstallPhase.notInstalled,
        message: 'com0com removed',
        downloadUrl: downloadPageUrl,
      );
      emit(success);
      return success;
    } catch (e) {
      final failed = Com0comInstallState(
        phase: Com0comInstallPhase.failed,
        message: 'Uninstall failed: $e',
        downloadUrl: downloadPageUrl,
        version: driverVersion,
      );
      emit(failed);
      return failed;
    }
  }

  Future<void> _deleteLocalBundle() async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(
      '${supportDir.path}${Platform.pathSeparator}com0com',
    );
    if (root.existsSync()) {
      try {
        root.deleteSync(recursive: true);
      } catch (_) {
        // ignore
      }
    }
  }

  Future<int> _uninstallDriver(Com0comSetupcLocation location) async {
    final escapedDir = location.workingDirectory.replaceAll("'", "''");
    final command = '''
Set-Location -LiteralPath '$escapedDir'
\$p = Start-Process -FilePath '.\\setupc.exe' -ArgumentList 'uninstall' -WorkingDirectory '$escapedDir' -Verb RunAs -PassThru -Wait
if (\$null -eq \$p) { exit 1223 }
exit \$p.ExitCode
''';
    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
      runInShell: true,
    );
    return result.exitCode;
  }

  Future<Com0comBundle> _downloadAndExtractBundle({
    required void Function(double progress) onProgress,
    void Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    final supportDir = await getApplicationSupportDirectory();
    final root = Directory(
      '${supportDir.path}${Platform.pathSeparator}com0com',
    );
    if (!root.existsSync()) {
      root.createSync(recursive: true);
    }

    final archDir = Directory(
      '${root.path}${Platform.pathSeparator}${Com0comPaths.archFolder}',
    );
    final setupc = File(
      '${archDir.path}${Platform.pathSeparator}setupc.exe',
    );
    if (await setupc.exists()) {
      onProgress(1);
      return Com0comBundle(
        root: root.path,
        archDir: archDir.path,
        executable: setupc.path,
      );
    }

    final zipPath =
        '${root.path}${Platform.pathSeparator}com0com-$driverVersion-manual.zip';
    await _downloadFile(
      url: manualInstallZipUrl,
      target: File(zipPath),
      onProgress: onProgress,
      onRetry: onRetry,
    );

    await _extractZip(zipPath, root.path);

    if (!await setupc.exists()) {
      throw StateError('setupc.exe missing after extracting $manualInstallZipUrl');
    }

    return Com0comBundle(
      root: root.path,
      archDir: archDir.path,
      executable: setupc.path,
    );
  }

  Future<void> _downloadFile({
    required String url,
    required File target,
    required void Function(double progress) onProgress,
    void Function(int attempt, int maxAttempts)? onRetry,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= downloadMaxAttempts; attempt++) {
      try {
        if (await target.exists()) {
          await target.delete();
        }
        await _downloadFileOnce(
          url: url,
          target: target,
          onProgress: onProgress,
        );
        return;
      } catch (e) {
        lastError = e;
        if (!_isRetryableDownloadError(e) || attempt >= downloadMaxAttempts) {
          break;
        }
        onProgress(0);
        onRetry?.call(attempt + 1, downloadMaxAttempts);
        await Future<void>.delayed(downloadRetryDelay * attempt);
      }
    }
    Error.throwWithStackTrace(
      lastError ?? StateError('Download failed'),
      StackTrace.current,
    );
  }

  bool _isRetryableDownloadError(Object error) {
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    if (error is HttpException) {
      return true;
    }
    final message = error.toString().toLowerCase();
    return message.contains('timeout') ||
        message.contains('semaphore') ||
        message.contains('connection') ||
        message.contains('reset');
  }

  Future<void> _downloadFileOnce({
    required String url,
    required File target,
    required void Function(double progress) onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 60);
    client.idleTimeout = const Duration(seconds: 90);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'pos_emulator/com0com-installer');
      request.headers.set('Accept', '*/*');
      final response = await request.close().timeout(const Duration(minutes: 5));

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }

      final total = response.contentLength;
      var received = 0;
      final sink = target.openWrite();

      await for (final chunk in response.timeout(const Duration(minutes: 5))) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }

      await sink.close();
      onProgress(1);
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _extractZip(String zipPath, String destPath) async {
    final escapedZip = zipPath.replaceAll("'", "''");
    final escapedDest = destPath.replaceAll("'", "''");
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        "Expand-Archive -LiteralPath '$escapedZip' -DestinationPath '$escapedDest' -Force",
      ],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw ProcessException(
        'Expand-Archive',
        const [],
        '${result.stdout}${result.stderr}',
        result.exitCode,
      );
    }
  }

  Future<int> _installDriver(Com0comBundle bundle) async {
    final escapedDir = bundle.archDir.replaceAll("'", "''");
    final command = '''
Set-Location -LiteralPath '$escapedDir'
\$env:CNC_INSTALL_CNCA0_CNCB0_PORTS='YES'
\$p1 = Start-Process -FilePath '.\\setupc.exe' -ArgumentList 'install','-','-' -WorkingDirectory '$escapedDir' -Verb RunAs -PassThru -Wait
if (\$null -eq \$p1) { exit 1223 }
if (\$p1.ExitCode -ne 0) { exit \$p1.ExitCode }
\$p2 = Start-Process -FilePath '.\\setupc.exe' -ArgumentList 'update' -WorkingDirectory '$escapedDir' -Verb RunAs -PassThru -Wait
if (\$null -eq \$p2) { exit 1223 }
exit \$p2.ExitCode
''';

    final result = await Process.run(
      'powershell',
      ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', command],
      runInShell: true,
    );
    return result.exitCode;
  }
}

class Com0comBundle {
  const Com0comBundle({
    required this.root,
    required this.archDir,
    required this.executable,
  });

  final String root;
  final String archDir;
  final String executable;
}

class Com0comSetupcLocation {
  const Com0comSetupcLocation({
    required this.executable,
    required this.workingDirectory,
  });

  final String executable;
  final String workingDirectory;
}

/// Locates setupc.exe in app bundle dir and standard install paths.
class Com0comPaths {
  static const archFolder = 'amd64';

  static const _programFilesCandidates = [
    r'C:\Program Files (x86)\com0com\setupc.exe',
    r'C:\Program Files\com0com\setupc.exe',
  ];

  Future<Com0comSetupcLocation?> locateSetupc() async {
    final supportDir = await getApplicationSupportDirectory();
    final bundled = File(
      '${supportDir.path}${Platform.pathSeparator}com0com'
      '${Platform.pathSeparator}$archFolder'
      '${Platform.pathSeparator}setupc.exe',
    );
    if (await bundled.exists()) {
      return Com0comSetupcLocation(
        executable: bundled.path,
        workingDirectory: bundled.parent.path,
      );
    }

    for (final path in _programFilesCandidates) {
      if (await File(path).exists()) {
        return Com0comSetupcLocation(
          executable: path,
          workingDirectory: File(path).parent.path,
        );
      }
    }

    try {
      final result = await Process.run(
        'where.exe',
        ['setupc.exe'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        final line = '$result.stdout'.split(RegExp(r'\r?\n')).firstWhere(
              (l) => l.trim().isNotEmpty,
              orElse: () => '',
            );
        if (line.isNotEmpty && await File(line.trim()).exists()) {
          final path = line.trim();
          return Com0comSetupcLocation(
            executable: path,
            workingDirectory: File(path).parent.path,
          );
        }
      }
    } catch (_) {
      // where.exe not available
    }

    return null;
  }

  Future<Com0comSetupcLocation?> waitForSetupc({
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final located = await locateSetupc();
      if (located != null && await verifySetupc(located)) {
        return located;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<bool> verifySetupc(Com0comSetupcLocation location) async {
    try {
      final result = await Process.run(
        location.executable,
        ['list'],
        workingDirectory: location.workingDirectory,
        runInShell: true,
      );
      final output = '${result.stdout}${result.stderr}'.toLowerCase();
      return output.contains('cnc') ||
          output.contains('com') ||
          result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Removes all com0com port pairs (best effort).
  Future<void> removeAllPortPairs(Com0comSetupcLocation location) async {
    for (var attempt = 0; attempt < 64; attempt++) {
      final listResult = await Process.run(
        location.executable,
        ['list'],
        workingDirectory: location.workingDirectory,
        runInShell: true,
      );
      final output = '${listResult.stdout}\n${listResult.stderr}';
      if (!output.toLowerCase().contains('com')) {
        return;
      }
      final removeResult = await Process.run(
        location.executable,
        ['remove', '0'],
        workingDirectory: location.workingDirectory,
        runInShell: true,
      );
      if (removeResult.exitCode != 0) {
        final lower = '${removeResult.stdout}${removeResult.stderr}'.toLowerCase();
        if (lower.contains('not found') || lower.contains('no ports')) {
          return;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<bool> removePair(
    Com0comSetupcLocation location, {
    required String emulatorPort,
    required String clientPort,
  }) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final listResult = await Process.run(
        location.executable,
        ['list'],
        workingDirectory: location.workingDirectory,
        runInShell: true,
      );
      final output = '${listResult.stdout}\n${listResult.stderr}';
      if (!output.contains(emulatorPort) && !output.contains(clientPort)) {
        return true;
      }
      final removeResult = await Process.run(
        location.executable,
        ['remove', '0'],
        workingDirectory: location.workingDirectory,
        runInShell: true,
      );
      if (removeResult.exitCode == 0) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }
}
