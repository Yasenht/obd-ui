import 'package:flutter_test/flutter_test.dart';

import 'package:DriveScope/ble_obd_service.dart';

/// اختبار قائمة الأوامر المدعومة في فيرموير Freematics v5
/// (telelogger.ino → processBLE، مع أوامر DTC الجديدة من رقعة firmware_patch/).
void main() {
  group('isCommandSupported (فيرموير v5)', () {
    test('أوامر قاعدة الفيرموير', () {
      expect(BleObdService.isCommandSupported('BATT'), isTrue);
      expect(BleObdService.isCommandSupported('ON'), isTrue);
      expect(BleObdService.isCommandSupported('ATE0'), isTrue);
      expect(BleObdService.isCommandSupported('VIN'), isTrue);
      expect(BleObdService.isCommandSupported('NET_OP'), isTrue);
      expect(BleObdService.isCommandSupported('RSSI'), isTrue);
    });

    test('معايرات Mode-01', () {
      expect(BleObdService.isCommandSupported('010C'), isTrue);
      expect(BleObdService.isCommandSupported('010D'), isTrue);
    });

    test('أوامر DTC الجديدة بعد الرقعة', () {
      expect(BleObdService.isCommandSupported('DTCS?'), isTrue);
      expect(BleObdService.isCommandSupported('DTC?'), isTrue);
      expect(BleObdService.isCommandSupported('DTCS>'), isTrue);
      expect(BleObdService.isCommandSupported('DTCCLR'), isTrue);
    });

    test('أوامر غير مدعومة في قاعدة الفيرموير v5', () {
      // تجيبها الفيرموير بـ "ERROR" قبل الترقية بـ firmware_patch/
      expect(BleObdService.isCommandSupported('03'), isFalse);
      expect(BleObdService.isCommandSupported('0902'), isFalse);
      expect(BleObdService.isCommandSupported('ATZ'), isFalse);
      expect(BleObdService.isCommandSupported('ATH0'), isFalse);
    });
  });
}
