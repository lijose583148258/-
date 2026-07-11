import 'package:flutter/services.dart';

enum DeviceFamily { xiaomi, oppo, honor, generic }

class DeviceCompatibilityProfile {
  final DeviceFamily family;
  final String manufacturer;
  final String model;
  final int sdkInt;

  const DeviceCompatibilityProfile({
    required this.family,
    required this.manufacturer,
    required this.model,
    required this.sdkInt,
  });

  factory DeviceCompatibilityProfile.fromMap(Map<Object?, Object?> map) {
    final manufacturer = map['manufacturer']?.toString() ?? '';
    return DeviceCompatibilityProfile.forManufacturer(
      manufacturer: manufacturer,
      model: map['model']?.toString() ?? '',
      sdkInt: int.tryParse(map['sdkInt']?.toString() ?? '') ?? 0,
    );
  }

  factory DeviceCompatibilityProfile.forManufacturer({
    required String manufacturer,
    String model = '',
    int sdkInt = 0,
  }) {
    final normalized = manufacturer.trim().toLowerCase();
    final family = switch (normalized) {
      'xiaomi' || 'redmi' || 'poco' => DeviceFamily.xiaomi,
      'oppo' || 'oneplus' || 'realme' => DeviceFamily.oppo,
      'honor' => DeviceFamily.honor,
      _ => DeviceFamily.generic,
    };
    return DeviceCompatibilityProfile(
      family: family,
      manufacturer: manufacturer.trim(),
      model: model.trim(),
      sdkInt: sdkInt,
    );
  }

  String get deviceLabel {
    final parts = [manufacturer, model].where((value) => value.isNotEmpty);
    final name = parts.join(' ');
    return name.isEmpty ? '当前 Android 设备' : name;
  }

  String get familyLabel => switch (family) {
    DeviceFamily.xiaomi => '小米 / Redmi / POCO（MIUI、HyperOS）',
    DeviceFamily.oppo => 'OPPO / OnePlus / realme（ColorOS）',
    DeviceFamily.honor => '荣耀（MagicOS）',
    DeviceFamily.generic => '标准 Android 兼容模式',
  };

  List<String> get guidance => switch (family) {
    DeviceFamily.xiaomi => const [
      '在“应用信息 → 权限”允许麦克风；若被拒绝，请在系统设置中重新开启。',
      '使用输入法或屏幕翻译时，不要在安全中心中强制结束应用；按系统提示允许相关服务。',
    ],
    DeviceFamily.oppo => const [
      '在“应用信息 → 权限管理”允许麦克风，并在权限弹窗被拦截时改从系统设置开启。',
      '若系统提示后台或自启动限制，仅在你需要输入法/无障碍功能持续可用时允许该项。',
    ],
    DeviceFamily.honor => const [
      '在“应用信息 → 权限”允许麦克风；拒绝后可从系统设置重新授予。',
      '若需要持续使用输入法或无障碍翻译，避免在系统清理中手动结束应用服务。',
    ],
    DeviceFamily.generic => const [
      '允许麦克风后即可使用语音输入；未安装语音识别或语音包时会自动改用手动输入。',
      '输入法和无障碍服务均由系统设置显式启用，应用不会在后台自动申请特殊权限。',
    ],
  };
}

class DeviceCompatibilityService {
  static const MethodChannel _channel = MethodChannel(
    'fanyitong/device_support',
  );

  static Future<DeviceCompatibilityProfile> getProfile() async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getDeviceProfile',
      );
      return DeviceCompatibilityProfile.fromMap(result ?? const {});
    } catch (_) {
      return DeviceCompatibilityProfile.forManufacturer(manufacturer: '');
    }
  }

  static Future<bool> openAppDetailsSettings() =>
      _open('openAppDetailsSettings');

  static Future<bool> openTextToSpeechSettings() =>
      _open('openTextToSpeechSettings');

  static Future<bool> openAccessibilitySettings() =>
      _open('openAccessibilitySettings');

  static Future<bool> _open(String method) async {
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } catch (_) {
      return false;
    }
  }
}
