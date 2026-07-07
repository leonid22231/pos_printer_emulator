import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../../core/errors/serial_port_exception.dart';
import '../../models/emulator_endpoint.dart';
import 'serial_port_service.dart';

/// Raw TCP print server (ESC/POS over socket, port 9100 by default).
class TcpPrintServerService implements SerialPortService {
  TcpPrintServerService({this.port = 9100});

  final int port;

  ServerSocket? _server;
  StreamSubscription<Socket>? _serverSubscription;
  Socket? _client;
  StreamSubscription<Uint8List>? _clientSubscription;
  final StreamController<Uint8List> _controller =
      StreamController<Uint8List>.broadcast();
  EmulatorEndpoint? _endpoint;

  @override
  Stream<Uint8List> get byteStream => _controller.stream;

  @override
  bool get isOpen => _server != null;

  EmulatorEndpoint? get endpoint => _endpoint;

  @override
  Future<List<String>> listAvailablePorts() async {
    return ['TCP:$port'];
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
    await close();

    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: true,
      );
    } on SocketException catch (e) {
      throw PortBusyException(
        'TCP:$port (${e.message}). '
        'Stop the emulator or close the other app using port $port.',
      );
    }

    _serverSubscription = _server!.listen(
      _onClient,
      onError: (Object error) {
        if (!_controller.isClosed) {
          _controller.addError(PortOpenException('TCP:$port', '$error'));
        }
      },
      cancelOnError: false,
    );

    _endpoint = EmulatorEndpoint(
      kind: EndpointKind.tcp,
      emulatorSide: 'TCP:$port (listening)',
      clientSide: '127.0.0.1:$port',
      instructions:
          'В кассе выберите сетевой/raw-принтер: 127.0.0.1, порт $port (RAW/9100).',
    );
  }

  void _onClient(Socket socket) {
    unawaited(_detachClient());
    _client = socket;

    _clientSubscription = socket.listen(
      (data) {
        if (data.isNotEmpty && !_controller.isClosed) {
          _controller.add(Uint8List.fromList(data));
        }
      },
      onDone: () {
        if (_client == socket) {
          _client = null;
        }
      },
      onError: (_) {
        if (_client == socket) {
          _client = null;
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> _detachClient() async {
    await _clientSubscription?.cancel();
    _clientSubscription = null;
    final client = _client;
    _client = null;
    if (client != null) {
      try {
        client.destroy();
      } catch (_) {
        try {
          await client.close();
        } catch (_) {
          // ignore
        }
      }
    }
  }

  @override
  Future<void> close() async {
    await _detachClient();

    await _serverSubscription?.cancel();
    _serverSubscription = null;

    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {
        // ignore
      }
    }

    _endpoint = null;
  }

  @override
  void dispose() {
    unawaited(close());
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
