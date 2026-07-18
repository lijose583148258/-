import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/services/device_compatibility_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceSupportChannel = MethodChannel('fanyitong/device_support');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceSupportChannel, null);
  });

  group('DeviceCompatibilityProfile', () {
    test('maps Xiaomi family variants to MIUI/HyperOS guidance', () {
      for (final manufacturer in ['Xiaomi', 'Redmi', 'POCO']) {
        final profile = DeviceCompatibilityProfile.forManufacturer(
          manufacturer: manufacturer,
          model: 'test-model',
          sdkInt: 36,
        );

        expect(profile.family, DeviceFamily.xiaomi);
        expect(profile.guidance, isNotEmpty);
        expect(profile.deviceLabel, contains(manufacturer));
      }
    });

    test('maps ColorOS family variants to OPPO guidance', () {
      for (final manufacturer in ['OPPO', 'OnePlus', 'realme']) {
        final profile = DeviceCompatibilityProfile.forManufacturer(
          manufacturer: manufacturer,
        );

        expect(profile.family, DeviceFamily.oppo);
        expect(profile.familyLabel, contains('ColorOS'));
      }
    });

    test('maps Honor devices to MagicOS guidance', () {
      final profile = DeviceCompatibilityProfile.forManufacturer(
        manufacturer: 'HONOR',
        model: 'Magic7',
      );

      expect(profile.family, DeviceFamily.honor);
      expect(profile.familyLabel, contains('MagicOS'));
      expect(profile.deviceLabel, 'HONOR Magic7');
    });

    test('uses safe generic guidance for an unknown manufacturer', () {
      final profile = DeviceCompatibilityProfile.forManufacturer(
        manufacturer: 'Example',
      );

      expect(profile.family, DeviceFamily.generic);
      expect(profile.guidance, hasLength(2));
    });

    test('normalizes noisy OEM manufacturer values', () {
      final cases = <String, DeviceFamily>{
        ' Xiaomi Communications Co., Ltd. ': DeviceFamily.xiaomi,
        'poco phone': DeviceFamily.xiaomi,
        'OPPO Electronics': DeviceFamily.oppo,
        'One Plus': DeviceFamily.oppo,
        'RealMe': DeviceFamily.oppo,
        'Oplus': DeviceFamily.oppo,
        'HONOR Device': DeviceFamily.honor,
        '荣耀': DeviceFamily.honor,
      };

      for (final entry in cases.entries) {
        final profile = DeviceCompatibilityProfile.forManufacturer(
          manufacturer: entry.key,
        );

        expect(
          profile.family,
          entry.value,
          reason: 'manufacturer=${entry.key}',
        );
      }
    });

    test('reads and trims profile values from the Android channel', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceSupportChannel, (call) async {
            expect(call.method, 'getDeviceProfile');
            return <String, Object?>{
              'manufacturer': ' One Plus ',
              'model': ' 12 ',
              'sdkInt': '36',
            };
          });

      final profile = await DeviceCompatibilityService.getProfile();

      expect(profile.family, DeviceFamily.oppo);
      expect(profile.manufacturer, 'One Plus');
      expect(profile.model, '12');
      expect(profile.sdkInt, 36);
    });

    test('falls back safely when Android settings channel fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(deviceSupportChannel, (call) async {
            throw PlatformException(code: 'unavailable');
          });

      final profile = await DeviceCompatibilityService.getProfile();
      final opened =
          await DeviceCompatibilityService.openTextToSpeechSettings();

      expect(profile.family, DeviceFamily.generic);
      expect(opened, isFalse);
    });
  });
}
