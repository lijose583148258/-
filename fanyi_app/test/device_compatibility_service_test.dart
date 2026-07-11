import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/services/device_compatibility_service.dart';

void main() {
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
  });
}
