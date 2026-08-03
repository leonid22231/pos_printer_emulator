import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/serial_port_exception.dart';
import 'serial_port_service.dart';

/// Mock serial source for development without hardware.
///
/// Feeds bytes from a sample ESC/POS stream with configurable chunk delay.
class MockSerialService implements SerialPortService {
  MockSerialService();

  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  Timer? _feedTimer;
  bool _open = false;
  int _index = 0;
  List<int> _sample = const [];

  @override
  Stream<Uint8List> get byteStream => _controller.stream;

  @override
  bool get isOpen => _open;

  @override
  Future<List<String>> listAvailablePorts() async {
    return const ['MOCK_COM1', 'MOCK_COM2'];
  }

  void setSampleData(List<int> data) {
    _sample = List<int>.from(data);
    _index = 0;
  }

  @override
  Future<void> open({
    required String portName,
    required int baudRate,
    required int dataBits,
    required int parity,
    required int stopBits,
    required int flowControl,
  }) async {
    if (_open) {
      await close();
    }
    if (_sample.isEmpty) {
      throw const PortOpenException('MOCK', 'No sample stream loaded');
    }
    _open = true;
    _index = 0;
    _startFeeding();
  }

  void _startFeeding() {
    _feedTimer?.cancel();
    _feedTimer = Timer.periodic(const Duration(milliseconds: 35), (_) {
      if (!_open || _index >= _sample.length) {
        _feedTimer?.cancel();
        return;
      }
      final chunkSize = (_index + 8 <= _sample.length) ? 8 : _sample.length - _index;
      final chunk = Uint8List.fromList(_sample.sublist(_index, _index + chunkSize));
      _index += chunkSize;
      if (!_controller.isClosed) {
        _controller.add(chunk);
      }
    });
  }

  /// Immediately push the entire sample (useful for tests).
  void pushAllAtOnce() {
    if (_sample.isEmpty || _controller.isClosed) {
      return;
    }
    _controller.add(Uint8List.fromList(_sample));
    _index = _sample.length;
  }

  /// Re-feed the loaded sample from the beginning (port stays open).
  Future<void> replay() async {
    if (!_open || _sample.isEmpty) {
      return;
    }
    _index = 0;
    _startFeeding();
  }

  @override
  Future<void> writeBytes(Uint8List bytes) async {}

  @override
  Future<void> close() async {
    _feedTimer?.cancel();
    _feedTimer = null;
    _open = false;
    _index = 0;
  }

  @override
  void dispose() {
    close();
    _controller.close();
  }
}
