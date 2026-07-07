/// Typed errors from the serial port layer.
sealed class SerialPortException implements Exception {
  const SerialPortException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PortNotFoundException extends SerialPortException {
  const PortNotFoundException(String port)
      : super('COM port not found: $port');
}

class PortBusyException extends SerialPortException {
  const PortBusyException(String port)
      : super('COM port is busy or already open: $port');
}

class PortAccessDeniedException extends SerialPortException {
  const PortAccessDeniedException(String port)
      : super('Access denied opening $port. Run as administrator or check permissions.');
}

class PortDisconnectedException extends SerialPortException {
  const PortDisconnectedException(String port)
      : super('Connection lost on $port');
}

class PortOpenException extends SerialPortException {
  const PortOpenException(String port, [String? details])
      : super(
          details == null
              ? 'Failed to open $port'
              : 'Failed to open $port: $details',
        );
}
