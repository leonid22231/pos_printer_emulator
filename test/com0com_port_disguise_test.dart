import 'package:flutter_test/flutter_test.dart';
import 'package:pos_emulator/services/serial/com0com_port_disguise.dart';

void main() {
  group('Com0comPortDisguise.parseClientPortId', () {
    test('finds CNCB id by PortName', () {
      const String listOutput = '''
        CNCA0 PortName=COM30,EmuBR=yes
        CNCB0 PortName=COM31,EmuBR=yes
      ''';

      expect(
        Com0comPortDisguise.parseClientPortId(listOutput, 'COM31'),
        'CNCB0',
      );
    });

    test('finds CNCB id by RealPortName', () {
      const String listOutput = '''
        CNCA2 PortName=COM#,RealPortName=COM30
        CNCB2 PortName=COM#,RealPortName=COM31
      ''';

      expect(
        Com0comPortDisguise.parseClientPortId(listOutput, 'com31'),
        'CNCB2',
      );
    });

    test('returns null when no CNCB line matches', () {
      const String listOutput = '''
        CNCA0 PortName=COM30
      ''';

      expect(
        Com0comPortDisguise.parseClientPortId(listOutput, 'COM99'),
        isNull,
      );
    });
  });
}
