/// Describes how external POS software should connect to this emulator.
enum EndpointKind {
  virtualCom,
  tcp,
  mock,
  manualCom,
}

class EmulatorEndpoint {
  const EmulatorEndpoint({
    required this.kind,
    required this.emulatorSide,
    required this.clientSide,
    required this.instructions,
  });

  /// Port opened by the emulator (internal).
  final String emulatorSide;

  /// Address the POS/cash register must use.
  final String clientSide;

  final EndpointKind kind;
  final String instructions;

  static const none = EmulatorEndpoint(
    kind: EndpointKind.virtualCom,
    emulatorSide: '',
    clientSide: '',
    instructions: '',
  );

  bool get isConfigured => clientSide.isNotEmpty;
}
