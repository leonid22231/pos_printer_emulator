/// Runtime status of the serial connection.
enum PortConnectionState {
  disconnected,
  connecting,
  connected,
  mock,
  error,
}

class PortStatus {
  const PortStatus({
    this.state = PortConnectionState.disconnected,
    this.message = 'Port closed',
    this.bytesReceived = 0,
    this.lastActivity,
    this.error,
  });

  final PortConnectionState state;
  final String message;
  final int bytesReceived;
  final DateTime? lastActivity;
  final String? error;

  bool get isActive =>
      state == PortConnectionState.connected ||
      state == PortConnectionState.mock;

  PortStatus copyWith({
    PortConnectionState? state,
    String? message,
    int? bytesReceived,
    DateTime? lastActivity,
    String? error,
    bool clearError = false,
  }) {
    return PortStatus(
      state: state ?? this.state,
      message: message ?? this.message,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      lastActivity: lastActivity ?? this.lastActivity,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
