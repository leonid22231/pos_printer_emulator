/// com0com driver install lifecycle for the virtual COM port feature.
enum Com0comInstallPhase {
  unknown,
  checking,
  notInstalled,
  downloading,
  installing,
  verifying,
  uninstalling,
  installed,
  failed,
}

class Com0comInstallState {
  const Com0comInstallState({
    this.phase = Com0comInstallPhase.unknown,
    this.progress,
    this.message,
    this.setupcPath,
    this.downloadUrl,
    this.version,
  });

  final Com0comInstallPhase phase;
  final double? progress;
  final String? message;
  final String? setupcPath;
  final String? downloadUrl;
  final String? version;

  bool get isInstalled => phase == Com0comInstallPhase.installed;

  bool get isBusy =>
      phase == Com0comInstallPhase.checking ||
      phase == Com0comInstallPhase.downloading ||
      phase == Com0comInstallPhase.installing ||
      phase == Com0comInstallPhase.verifying ||
      phase == Com0comInstallPhase.uninstalling;

  Com0comInstallState copyWith({
    Com0comInstallPhase? phase,
    double? progress,
    String? message,
    String? setupcPath,
    String? downloadUrl,
    String? version,
    bool clearProgress = false,
  }) {
    return Com0comInstallState(
      phase: phase ?? this.phase,
      progress: clearProgress ? null : (progress ?? this.progress),
      message: message ?? this.message,
      setupcPath: setupcPath ?? this.setupcPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      version: version ?? this.version,
    );
  }
}
