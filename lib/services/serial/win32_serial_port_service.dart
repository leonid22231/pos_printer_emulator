import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:serial_port_win32/serial_port_win32.dart';

import '../../core/errors/serial_port_exception.dart';
import 'serial_port_service.dart';

/// Windows COM port implementation using [serial_port_win32].
///
/// Why serial_port_win32 over libserialport_plus:
/// - Native Win32 API — no extra CMake/FFI build step for libserialport on Windows.
/// - Direct access to DCB parity/stop bits and registry-based port enumeration.
/// - Mature Windows-only package aligned with this project's scope.
class Win32SerialPortService implements SerialPortService {
  Win32SerialPortService();

  SerialPort? _port;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List?>? _readLoop;
  bool _reading = false;
  String? _portName;

  @override
  Stream<Uint8List> get byteStream => _controller.stream;

  @override
  bool get isOpen => _port?.isOpened ?? false;

  /// Enumerate COM ports via Windows registry (e.g. COM3, COM4).
  @override
  Future<List<String>> listAvailablePorts() async {
    try {
      return SerialPort.getAvailablePorts();
    } catch (e) {
      throw PortOpenException('?', 'Failed to enumerate ports: $e');
    }
  }

  /// Open selected COM port with Win32 DCB settings.
  ///
  /// serial_port_win32 requires the port to be open before BaudRate/Parity setters
  /// work — they throw "INVALID_HANDLE_VALUE" if called on a closed handle.
  /// Settings are passed via the constructor, then re-applied after [SerialPort.open].
  @override
  Future<void> open({
    required String portName,
    required int baudRate,
    required int dataBits,
    required int parity,
    required int stopBits,
    required int flowControl,
  }) async {
    await close();

    final available = await listAvailablePorts();
    if (!available.contains(portName)) {
      throw PortNotFoundException(portName);
    }

    try {
      // Factory caches instances per port name — constructor params apply on first
      // creation; after open we always re-apply the requested DCB via setters.
      _port = SerialPort(
        portName,
        openNow: false,
        BaudRate: baudRate,
        ByteSize: dataBits,
        Parity: parity,
        StopBits: stopBits,
      );

      await _port!.open();

      _port!
        ..BaudRate = baudRate
        ..ByteSize = dataBits
        ..Parity = parity
        ..StopBits = stopBits;

      _applyFlowControl(flowControl);

      _portName = portName;
      _startReadLoop();
    } on FileSystemException catch (e) {
      _port = null;
      throw _mapFileSystemError(portName, e);
    } on Exception catch (e) {
      _port = null;
      throw _mapOpenException(portName, e);
    }
  }

  void _applyFlowControl(int flowControl) {
    final port = _port;
    if (port == null) {
      return;
    }
  }

  void _startReadLoop() {
    _reading = true;
    _readLoop?.cancel();
    _readLoop = Stream.periodic(const Duration(milliseconds: 20))
        .asyncMap((_) => _readChunk())
        .listen(
      (chunk) {
        if (chunk != null && chunk.isNotEmpty && !_controller.isClosed) {
          _controller.add(chunk);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_controller.isClosed) {
          _controller.addError(
            PortDisconnectedException(_portName ?? 'unknown'),
          );
        }
      },
    );
  }

  Future<Uint8List?> _readChunk() async {
    final port = _port;
    if (!_reading || port == null || !port.isOpened) {
      return null;
    }
    try {
      final data = await port.readBytes(
        512,
        timeout: const Duration(milliseconds: 50),
      );
      if (data.isEmpty) {
        return null;
      }
      return data;
    } catch (e) {
      if (_reading) {
        _controller.addError(
          PortDisconnectedException(_portName ?? 'unknown'),
        );
        await close();
      }
      return null;
    }
  }

  @override
  Future<void> close() async {
    _reading = false;
    await _readLoop?.cancel();
    _readLoop = null;
    final port = _port;
    _port = null;
    _portName = null;
    if (port != null) {
      try {
        if (port.isOpened) {
          port.close();
        }
      } catch (_) {
        // ignore close errors
      }
    }
  }

  @override
  void dispose() {
    _reading = false;
    _readLoop?.cancel();
    final port = _port;
    _port = null;
    if (port != null) {
      try {
        if (port.isOpened) {
          port.close();
        }
      } catch (_) {
        // ignore
      }
    }
    if (!_controller.isClosed) {
      _controller.close();
    }
  }

  SerialPortException _mapOpenException(String portName, Exception e) {
    final message = e.toString();

    if (message.contains('INVALID_HANDLE_VALUE')) {
      return PortOpenException(
        portName,
        'Internal serial port state error. Retry closing and reopening the port.',
      );
    }
    if (message.contains('Access is denied') ||
        message.contains('access denied') ||
        message.contains('error code is 5')) {
      return PortAccessDeniedException(portName);
    }
    if (message.contains('not available') ||
        message.contains('not found') ||
        message.contains('error code is 2')) {
      return PortNotFoundException(portName);
    }
    if (message.contains('being used') ||
        message.contains('busy') ||
        message.contains('error code is 32')) {
      return PortBusyException(portName);
    }
    if (message.contains('has been opened')) {
      return PortBusyException(portName);
    }

    return PortOpenException(portName, message);
  }

  SerialPortException _mapFileSystemError(
    String portName,
    FileSystemException e,
  ) {
    final message = e.message.toLowerCase();
    if (message.contains('access') || message.contains('denied')) {
      return PortAccessDeniedException(portName);
    }
    if (message.contains('not found') || message.contains('cannot find')) {
      return PortNotFoundException(portName);
    }
    if (message.contains('busy') || message.contains('use')) {
      return PortBusyException(portName);
    }
    return PortOpenException(portName, e.message);
  }
}

/// Map domain parity/stop bits to Win32 DCB integer constants.
int mapParityToWin32(String parity) {
  return switch (parity) {
    'O' => 1, // ODDPARITY
    'E' => 2, // EVENPARITY
    'M' => 3, // MARKPARITY
    'S' => 4, // SPACEPARITY
    _ => 0, // NOPARITY
  };
}

int mapStopBitsToWin32(String stopBits) {
  return switch (stopBits) {
    '1.5' => 1, // ONE5STOPBITS
    '2' => 2, // TWOSTOPBITS
    _ => 0, // ONESTOPBIT
  };
}
