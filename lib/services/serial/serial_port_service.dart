import 'dart:async';
import 'dart:typed_data';

/// Abstraction over real COM port and mock stream sources.
abstract class SerialPortService {
  Stream<Uint8List> get byteStream;
  bool get isOpen;

  Future<List<String>> listAvailablePorts();

  Future<void> open({
    required String portName,
    required int baudRate,
    required int dataBits,
    required int parity,
    required int stopBits,
    required int flowControl,
  });

  /// Optional TX path (DLE EOT replies, ASB). No-op when unsupported.
  Future<void> writeBytes(Uint8List bytes) async {}

  Future<void> close();

  void dispose();
}
