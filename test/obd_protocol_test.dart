import 'package:flutter_test/flutter_test.dart';

import '../lib/obd_protocol.dart';

void main() {
  test('يفك RPM من رد ELM327', () {
    final reading = ObdParser.parsePid(pid: 0x0C, response: '41 0C 1A F8\r');
    expect(reading.value, 1726);
    expect(reading.unit, 'RPM');
  });

  test('يفك حرارة سائل التبريد', () {
    final reading = ObdParser.parsePid(pid: 0x05, response: '41 05 7B\r');
    expect(reading.value, 83);
    expect(reading.unit, '°C');
  });

  test('يفك أكواد DTC القياسية', () {
    final codes = ObdParser.parseDtc('43 01 08 01 09 00 00\r');
    expect(codes, ['P0108', 'P0109']);
  });

  test('يفك VIN متعدد الأسطر', () {
    final vin = ObdParser.parseVin('0: 49 02 01 57 56 57 5A 5A\r\n1: 38 5A 57 31 32 33 34 35 36 37 38 39 30 31 32 33 34\r');
    expect(vin, 'WVWZZ8ZW123456789');
  });

  test('يتعرف على أخطاء ELM327', () {
    expect(ObdParser.isError('NO DATA\r'), isTrue);
    expect(ObdParser.isError('41 0C 1A F8\r'), isFalse);
  });
}
