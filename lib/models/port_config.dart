/// Serial port connection parameters.
class PortConfig {
  const PortConfig({
    this.portName = '',
    this.baudRate = 9600,
    this.dataBits = 8,
    this.parity = Parity.none,
    this.stopBits = StopBits.one,
    this.flowControl = FlowControl.none,
  });

  final String portName;
  final int baudRate;
  final int dataBits;
  final Parity parity;
  final StopBits stopBits;
  final FlowControl flowControl;

  PortConfig copyWith({
    String? portName,
    int? baudRate,
    int? dataBits,
    Parity? parity,
    StopBits? stopBits,
    FlowControl? flowControl,
  }) {
    return PortConfig(
      portName: portName ?? this.portName,
      baudRate: baudRate ?? this.baudRate,
      dataBits: dataBits ?? this.dataBits,
      parity: parity ?? this.parity,
      stopBits: stopBits ?? this.stopBits,
      flowControl: flowControl ?? this.flowControl,
    );
  }

  String get summary {
    final serial = '$baudRate $dataBits${parity.label}${stopBits.label}';
    if (portName.isEmpty) {
      return serial;
    }
    return '$portName · $serial';
  }

  static const List<int> commonBaudRates = [
    1200,
    2400,
    4800,
    9600,
    19200,
    38400,
    57600,
    115200,
  ];
}

enum Parity {
  none('N'),
  odd('O'),
  even('E'),
  mark('M'),
  space('S');

  const Parity(this.label);
  final String label;
}

enum StopBits {
  one('1'),
  onePointFive('1.5'),
  two('2');

  const StopBits(this.label);
  final String label;
}

enum FlowControl {
  none('None'),
  rtsCts('RTS/CTS'),
  xonXoff('XON/XOFF');

  const FlowControl(this.label);
  final String label;
}
