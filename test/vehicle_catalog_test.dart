import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:DriveScope/controllers/app_controller.dart';
import 'package:DriveScope/services/vehicle_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('قاعدة الدعم: 2005 وما قبلها غير مدعومة، و2006 فأحدث مدعوم', () {
    expect(VehicleCatalog.isYearSupported(1980), isFalse);
    expect(VehicleCatalog.isYearSupported(2005), isFalse);
    expect(VehicleCatalog.isYearSupported(2006), isTrue);
    expect(VehicleCatalog.isYearSupported(2026), isTrue);
  });

  test('الكتالوج: كل ماركة لها موديلات، والسنوات تنازلية حتى 1960', () {
    for (final make in VehicleCatalog.makes) {
      expect(VehicleCatalog.modelsFor(make), isNotEmpty,
          reason: 'موديلات $make فارغة');
    }
    final years = VehicleCatalog.years();
    expect(years.first, DateTime.now().year);
    expect(years.last, 1960);
    // تنازلي بلا تكرار.
    for (var i = 0; i < years.length - 1; i++) {
      expect(years[i], years[i + 1] + 1);
    }
    expect(VehicleCatalog.modelsFor('Toyota'), contains('Corolla'));
  });

  test('مركبة 1980 (Toyota Corolla) تُحجب: الأوامر لا تُرسل', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.loadPreferences();

    await controller.setVehicle(make: 'Toyota', model: 'Corolla', year: 1980);
    expect(controller.hasVehicleSelection, isTrue);
    expect(controller.vehicleLabel, '1980 Toyota Corolla');
    expect(controller.vehicleUnsupported, isTrue);

    // أي أمر (حتى قبل الاتصال بالجهاز) يُرفض بسب الدعم، لا الاتصال.
    final response = await controller.executeCommand('فحص', '0105\r');
    expect(response, isNull);
    expect(controller.error, contains('المركبة غير مدعومة'));
  });

  test('مركبة 2006 تُسمح بالأوامر: الخطأ هو غير الاتصال المعتاد', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.loadPreferences();

    await controller.setVehicle(make: 'Toyota', model: 'Corolla', year: 2006);
    expect(controller.vehicleUnsupported, isFalse);

    await controller.executeCommand('فحص', '0105\r');
    // الأرسال لم يمنع بسبب المنتج — رسالة الخطأ هي رسالة الاتصال المعيارية.
    expect(controller.error, contains('اتصل بجهاز BLE أولاً'));
  });

  test('غياب اختيار المركبة لا يحجب الأوامر (سطر قديم متوافق)', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.loadPreferences();

    expect(controller.hasVehicleSelection, isFalse);
    expect(controller.vehicleUnsupported, isFalse);

    await controller.executeCommand('فحص', '0105\r');
    expect(controller.error, contains('اتصل بجهاز BLE أولاً'));
  });

  test('اختيار المركبة يُحفظ محلياً ويُستعاد عند الإقلاع', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.loadPreferences();
    await controller.setVehicle(
      make: 'Toyota',
      model: 'Corolla',
      year: 1980,
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('vehicle_make_v1'), 'Toyota');
    expect(prefs.getString('vehicle_model_v1'), 'Corolla');
    expect(prefs.getInt('vehicle_year_v1'), 1980);

    // كنترولر جديد (محاكاة إقلاع جديد) يستعيد الاختيار وحالة الحجب.
    final second = AppController();
    await second.loadPreferences();
    expect(second.vehicleLabel, '1980 Toyota Corolla');
    expect(second.vehicleUnsupported, isTrue);

    // المسح يعيد السلوك الافتراضي ويحذف التخزين.
    await second.clearVehicle();
    expect(second.hasVehicleSelection, isFalse);
    final prefsAfterClear = await SharedPreferences.getInstance();
    expect(prefsAfterClear.getString('vehicle_make_v1'), isNull);
  });

  test('تغيير الماركة يعيد ضبط الموديل فقط', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController();
    await controller.loadPreferences();

    await controller.setVehicle(make: 'Toyota', model: 'Corolla', year: 2010);
    expect(controller.vehicleLabel, '2010 Toyota Corolla');

    await controller.setVehicle(make: 'Nissan');
    expect(controller.vehicleMake, 'Nissan');
    expect(controller.vehicleModel, isNull); // الموديل أُعيد الضبط.
    expect(controller.vehicleYear, 2010); // السنة بقيت.
  });
}
