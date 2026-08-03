import 'dart:async';
import 'dart:typed_data';

import '../../core/errors/serial_port_exception.dart';
import '../../models/emulator_endpoint.dart';
import '../../models/virtual_transport.dart';
import 'com0com_manager.dart';
import 'serial_port_service.dart';
import 'tcp_print_server_service.dart';
import 'win32_serial_port_service.dart';

/// Primary emulator transport: creates a virtual endpoint for POS software.
///
/// [VirtualTransport.com] — virtual COM pair via com0com (requires driver).
/// [VirtualTransport.tcp] — raw TCP print server on port 9100.
class VirtualEmulatorService implements SerialPortService {
  VirtualEmulatorService({
    Com0comManager? com0com,
    Win32SerialPortService? serial,
    TcpPrintServerService? tcp,
  })  : _com0com = com0com ?? Com0comManager(),
        _serial = serial ?? Win32SerialPortService(),
        _tcp = tcp ?? TcpPrintServerService();

  final Com0comManager _com0com;
  final Win32SerialPortService _serial;
  final TcpPrintServerService _tcp;

  SerialPortService? _active;
  EmulatorEndpoint? _endpoint;
  Com0comPair? _activePair;
  bool _createdPairThisSession = false;

  @override
  Stream<Uint8List> get byteStream =>
      _active?.byteStream ?? const Stream.empty();

  @override
  bool get isOpen => _active?.isOpen ?? false;

  EmulatorEndpoint? get endpoint => _endpoint;

  @override
  Future<List<String>> listAvailablePorts() async {
    return const ['COM', 'TCP:9100'];
  }

  @override
  Future<void> open({
    required String portName,
    required int baudRate,
    required int dataBits,
    required int parity,
    required int stopBits,
    required int flowControl,
    VirtualTransport transport = VirtualTransport.com,
  }) async {
    await close();

    if (transport == VirtualTransport.com) {
      if (!await _com0com.isInstalled()) {
        throw const PortOpenException(
          'COM',
          'com0com is not installed',
        );
      }

      final pair = await _com0com.createPair();
      if (pair == null) {
        throw const PortOpenException(
          'COM',
          'Failed to create virtual COM pair',
        );
      }

      try {
        await _serial.open(
          portName: pair.emulatorPort,
          baudRate: baudRate,
          dataBits: dataBits,
          parity: parity,
          stopBits: stopBits,
          flowControl: flowControl,
        );
        _active = _serial;
        _activePair = pair;
        _createdPairThisSession = true;
        _endpoint = EmulatorEndpoint(
          kind: EndpointKind.virtualCom,
          emulatorSide: pair.emulatorPort,
          clientSide: pair.clientPort,
          instructions:
              'В кассовой программе укажите принтер на порту ${pair.clientPort}. '
              'Эмулятор слушает ${pair.emulatorPort} (вторая сторона пары com0com).',
        );
        return;
      } on SerialPortException {
        await _serial.close();
        rethrow;
      }
    }

    await _tcp.open(
      portName: 'TCP',
      baudRate: baudRate,
      dataBits: dataBits,
      parity: parity,
      stopBits: stopBits,
      flowControl: flowControl,
    );
    _active = _tcp;
    _endpoint = _tcp.endpoint;
  }

  @override
  Future<void> writeBytes(Uint8List bytes) async {
    final active = _active;
    if (active == null) {
      return;
    }
    await active.writeBytes(bytes);
  }

  @override
  Future<void> close() async {
    await _serial.close();
    await _tcp.close();
    if (_createdPairThisSession && _activePair != null) {
      await _com0com.releasePair(_activePair);
    }
    _activePair = null;
    _createdPairThisSession = false;
    _active = null;
    _endpoint = null;
  }

  @override
  void dispose() {
    unawaited(close());
    _serial.dispose();
    _tcp.dispose();
  }
}
