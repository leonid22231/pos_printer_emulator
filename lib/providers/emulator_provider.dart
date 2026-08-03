import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/serial_port_exception.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_provider.dart';
import '../models/com0com_install_state.dart';
import '../models/emulator_endpoint.dart';
import '../models/log_entry.dart';
import '../models/port_config.dart';
import '../models/port_status.dart';
import '../models/receipt_document.dart';
import '../models/virtual_transport.dart';
import '../services/escpos/escpos_parser.dart';
import '../services/samples/sample_receipt_builder.dart';
import '../services/serial/com0com_manager.dart';
import '../services/serial/mock_serial_service.dart';
import '../services/serial/serial_port_service.dart';
import '../services/serial/virtual_emulator_service.dart';
import '../services/session/session_log_service.dart';

enum ConnectionMode { virtual, mock }

class EmulatorState {
  const EmulatorState({
    this.config = const PortConfig(),
    this.status = const PortStatus(),
    this.endpoint = EmulatorEndpoint.none,
    this.com0comState = const Com0comInstallState(),
    this.logEntries = const [],
    this.receipt = const ReceiptDocument(),
    this.mode = ConnectionMode.virtual,
    this.virtualTransport = VirtualTransport.com,
    this.isBusy = false,
  });

  final PortConfig config;
  final PortStatus status;
  final EmulatorEndpoint endpoint;
  final Com0comInstallState com0comState;
  final List<LogEntry> logEntries;
  final ReceiptDocument receipt;
  final ConnectionMode mode;
  final VirtualTransport virtualTransport;
  final bool isBusy;

  EmulatorState copyWith({
    PortConfig? config,
    PortStatus? status,
    EmulatorEndpoint? endpoint,
    Com0comInstallState? com0comState,
    List<LogEntry>? logEntries,
    ReceiptDocument? receipt,
    ConnectionMode? mode,
    VirtualTransport? virtualTransport,
    bool? isBusy,
  }) {
    return EmulatorState(
      config: config ?? this.config,
      status: status ?? this.status,
      endpoint: endpoint ?? this.endpoint,
      com0comState: com0comState ?? this.com0comState,
      logEntries: logEntries ?? this.logEntries,
      receipt: receipt ?? this.receipt,
      mode: mode ?? this.mode,
      virtualTransport: virtualTransport ?? this.virtualTransport,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

/// Central application state — Riverpod [Notifier] keeps UI and services in sync.
class EmulatorNotifier extends Notifier<EmulatorState> {
  late final VirtualEmulatorService _virtual;
  late final MockSerialService _mock;
  late final Com0comManager _com0com;
  late final EscPosParser _parser;
  late final SessionLogService _sessionLog;

  StreamSubscription<Uint8List>? _byteSubscription;
  bool _shuttingDown = false;

  SerialPortService get _activeService =>
      state.mode == ConnectionMode.mock ? _mock : _virtual;

  @override
  EmulatorState build() {
    _com0com = Com0comManager();
    _virtual = VirtualEmulatorService(com0com: _com0com);
    _mock = MockSerialService();
    _parser = EscPosParser();
    _sessionLog = SessionLogService();

    ref.onDispose(() {
      unawaited(shutdown());
    });

    Future.microtask(refreshEnvironment);
    return const EmulatorState();
  }

  AppStrings get _s => ref.read(stringsProvider);

  void updateConfig(PortConfig config) {
    state = state.copyWith(config: config);
  }

  void setMode(ConnectionMode mode) {
    unawaited(_applyMode(mode));
  }

  void setVirtualTransport(VirtualTransport transport) {
    unawaited(_applyVirtualTransport(transport));
  }

  Future<void> _applyMode(ConnectionMode mode) async {
    if (state.mode == mode) {
      return;
    }
    if (state.status.isActive || state.isBusy) {
      await closePort();
    }
    _resetReceiptPreview();
    state = state.copyWith(
      mode: mode,
      status: PortStatus(
        state: PortConnectionState.disconnected,
        message: _idleStatusMessage(mode, state.virtualTransport),
        bytesReceived: state.status.bytesReceived,
        lastActivity: state.status.lastActivity,
      ),
    );
  }

  Future<void> _applyVirtualTransport(VirtualTransport transport) async {
    if (state.virtualTransport == transport) {
      return;
    }
    if (state.status.isActive || state.isBusy) {
      await closePort();
    }
    if (state.mode == ConnectionMode.virtual) {
      _resetReceiptPreview();
    }
    state = state.copyWith(
      virtualTransport: transport,
      status: state.mode == ConnectionMode.virtual
          ? PortStatus(
              state: PortConnectionState.disconnected,
              message: _idleStatusMessage(ConnectionMode.virtual, transport),
              bytesReceived: state.status.bytesReceived,
              lastActivity: state.status.lastActivity,
            )
          : state.status,
    );
  }

  String _idleStatusMessage(ConnectionMode mode, VirtualTransport transport) {
    return _s.idleStatusHint(
      demoMode: mode == ConnectionMode.mock,
      tcpTransport: transport == VirtualTransport.tcp,
    );
  }

  void _resetReceiptPreview() {
    _parser.reset();
    state = state.copyWith(receipt: const ReceiptDocument());
  }

  Future<void> refreshEnvironment() async {
    final installState = await _com0com.checkInstallation();
    state = state.copyWith(com0comState: installState);
    if (installState.isInstalled) {
      _addEvent(
        _s.eventCom0comReady(installState.version ?? ''),
        LogEntryKind.event,
      );
    } else {
      _addEvent(_s.eventCom0comMissing, LogEntryKind.event);
    }
  }

  Future<void> installCom0com() async {
    if (state.com0comState.isBusy) {
      return;
    }

    state = state.copyWith(
      com0comState: state.com0comState.copyWith(
        phase: Com0comInstallPhase.checking,
        message: '…',
      ),
    );

    final result = await _com0com.install(
      onProgress: (installState) {
        state = state.copyWith(com0comState: installState);
      },
    );

    state = state.copyWith(com0comState: result);
    _addEvent(result.message ?? 'com0com', LogEntryKind.event);
  }

  Future<void> uninstallCom0com() async {
    if (state.com0comState.isBusy) {
      return;
    }

    await shutdown();
    state = state.copyWith(
      com0comState: state.com0comState.copyWith(
        phase: Com0comInstallPhase.uninstalling,
      ),
    );

    final result = await _com0com.uninstall(
      onProgress: (installState) {
        state = state.copyWith(com0comState: installState);
      },
    );

    state = state.copyWith(
      com0comState: result,
      endpoint: EmulatorEndpoint.none,
      status: const PortStatus(
        state: PortConnectionState.disconnected,
        message: 'stopped',
      ),
    );
    _addEvent(result.message ?? 'com0com', LogEntryKind.event);
  }

  Future<void> openPort() async {
    if (state.status.isActive || state.isBusy || _shuttingDown) {
      return;
    }

    final config = state.config;

    state = state.copyWith(
      isBusy: true,
      status: state.status.copyWith(
        state: PortConnectionState.connecting,
        message: '…',
        clearError: true,
      ),
    );

    try {
      await shutdown();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (state.mode == ConnectionMode.virtual) {
        _resetReceiptPreview();
      }

      if (state.mode == ConnectionMode.mock) {
        _mock.setSampleData(SampleReceiptBuilder.buildCoffeeShopReceipt());
        await _activeService.open(
          portName: 'MOCK',
          baudRate: config.baudRate,
          dataBits: config.dataBits,
          parity: 0,
          stopBits: 0,
          flowControl: 0,
        );
      } else {
        if (state.virtualTransport == VirtualTransport.com &&
            !state.com0comState.isInstalled) {
          await installCom0com();
          if (!state.com0comState.isInstalled) {
            throw PortOpenException(
              'COM',
              _s.com0comRequiredForComMode,
            );
          }
        }

        await _virtual.open(
          portName: '',
          baudRate: config.baudRate,
          dataBits: config.dataBits,
          parity: mapParityToWin32(config.parity.label),
          stopBits: mapStopBitsToWin32(config.stopBits.label),
          flowControl: 0,
          transport: state.virtualTransport,
        );
      }

      await _byteSubscription?.cancel();
      _byteSubscription = _activeService.byteStream.listen(
        _onBytes,
        onError: _onStreamError,
        cancelOnError: false,
      );

      final endpoint = state.mode == ConnectionMode.mock
          ? const EmulatorEndpoint(
              kind: EndpointKind.mock,
              emulatorSide: 'MOCK',
              clientSide: 'MOCK',
              instructions: 'Demo ESC/POS stream',
            )
          : (_virtual.endpoint ?? EmulatorEndpoint.none);

      state = state.copyWith(
        isBusy: false,
        endpoint: endpoint,
        status: PortStatus(
          state: state.mode == ConnectionMode.mock
              ? PortConnectionState.mock
              : PortConnectionState.connected,
          message: endpoint.clientSide,
          bytesReceived: 0,
          lastActivity: DateTime.now(),
        ),
      );
      _addEvent(endpoint.instructions, LogEntryKind.event);
    } on SerialPortException catch (e) {
      await shutdown();
      state = state.copyWith(
        isBusy: false,
        status: PortStatus(
          state: PortConnectionState.error,
          message: e.message,
          error: e.message,
        ),
      );
      _addEvent(e.message, LogEntryKind.error);
    } catch (e) {
      await shutdown();
      state = state.copyWith(
        isBusy: false,
        status: PortStatus(
          state: PortConnectionState.error,
          message: '$e',
          error: '$e',
        ),
      );
      _addEvent('$e', LogEntryKind.error);
    }
  }

  Future<void> shutdown() async {
    if (_shuttingDown) {
      return;
    }
    _shuttingDown = true;
    try {
      await _byteSubscription?.cancel();
      _byteSubscription = null;
      await _virtual.close();
      await _mock.close();
    } finally {
      _shuttingDown = false;
    }
  }

  Future<void> closePort() async {
    await shutdown();
    state = state.copyWith(
      endpoint: EmulatorEndpoint.none,
      status: PortStatus(
        state: PortConnectionState.disconnected,
        message: _s.eventEmulatorStopped,
      ),
    );
    _addEvent(_s.eventEmulatorStopped, LogEntryKind.event);
  }

  void clear() {
    _resetReceiptPreview();
    state = state.copyWith(
      logEntries: const [],
      status: state.status.copyWith(bytesReceived: 0),
    );
    _addEvent(_s.eventBufferCleared, LogEntryKind.event);
  }

  Future<void> loadDemoReceipt({bool openAfterLoad = true}) async {
    _mock.setSampleData(SampleReceiptBuilder.buildCoffeeShopReceipt());
    _addEvent(_s.eventDemoLoaded, LogEntryKind.event);

    if (!openAfterLoad) {
      state = state.copyWith(mode: ConnectionMode.mock);
      return;
    }

    if (state.status.isActive && state.mode == ConnectionMode.mock) {
      await _mock.replay();
      return;
    }

    if (state.status.isActive) {
      await closePort();
    }

    final fromVirtual = state.mode == ConnectionMode.virtual;
    state = state.copyWith(mode: ConnectionMode.mock);
    if (fromVirtual) {
      _resetReceiptPreview();
    }
    await openPort();
  }

  Future<String?> saveLogs({File? target}) async {
    try {
      final file = target ?? await _sessionLog.defaultLogFile();
      await _sessionLog.saveLogs(
        file: file,
        entries: state.logEntries,
        plainText: state.receipt.plainText,
      );
      _addEvent(_s.logsSaved(file.path), LogEntryKind.event);
      return file.path;
    } catch (e) {
      _addEvent(_s.saveFailed('$e'), LogEntryKind.error);
      return null;
    }
  }

  void _onBytes(Uint8List chunk) {
    final bytes = chunk.toList();
    _parser.feed(bytes);

    final replies = _parser.consumeReplies();
    if (replies.isNotEmpty) {
      unawaited(_activeService.writeBytes(replies));
    }

    final parserLogs = _parser.consumeLogs();
    final hexEntry = LogEntry(
      timestamp: DateTime.now(),
      kind: LogEntryKind.rawHex,
      message: _formatHex(bytes),
      bytes: bytes,
    );

    state = state.copyWith(
      receipt: _parser.document,
      logEntries: [...state.logEntries, hexEntry, ...parserLogs],
      status: state.status.copyWith(
        bytesReceived: state.status.bytesReceived + bytes.length,
        lastActivity: DateTime.now(),
      ),
    );
  }

  void _onStreamError(Object error) {
    final message = error is SerialPortException
        ? error.message
        : 'Stream error: $error';
    state = state.copyWith(
      status: PortStatus(
        state: PortConnectionState.error,
        message: message,
        error: message,
        bytesReceived: state.status.bytesReceived,
        lastActivity: DateTime.now(),
      ),
    );
    _addEvent(message, LogEntryKind.error);
  }

  void _addEvent(String message, LogEntryKind kind) {
    state = state.copyWith(
      logEntries: [
        ...state.logEntries,
        LogEntry(
          timestamp: DateTime.now(),
          kind: kind,
          message: message,
        ),
      ],
    );
  }

  String _formatHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }
}

int mapParityToWin32(String parity) {
  return switch (parity) {
    'O' => 1,
    'E' => 2,
    'M' => 3,
    'S' => 4,
    _ => 0,
  };
}

int mapStopBitsToWin32(String stopBits) {
  return switch (stopBits) {
    '1.5' => 1,
    '2' => 2,
    _ => 0,
  };
}

final emulatorProvider =
    NotifierProvider<EmulatorNotifier, EmulatorState>(EmulatorNotifier.new);
