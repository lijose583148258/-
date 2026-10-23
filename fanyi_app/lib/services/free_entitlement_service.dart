/// 自有 APP 的永久免费权益层。
///
/// 这个服务用于把所有功能统一声明为“已开放”，以后新增功能时也从这里读取，
/// 避免在页面里散落会员、订阅或试用判断。
class FreeEntitlementService {
  FreeEntitlementService._();

  static const String editionName = '无会员完整版本';
  static const bool isMembershipEnabled = false;
  static const bool isPremiumUser = true;
  static const bool areAllFeaturesUnlocked = true;

  static const List<String> unlockedFeatures = [
    '中越双向翻译',
    '对话翻译',
    '课程树',
    '关卡练习',
    '学习进度',
    '连击积分',
    '成就系统',
    '拍照识别',
    '本地词典',
    '俚语词库',
    '语音朗读',
    '翻译历史',
    '输入法辅助',
    '桌面小组件',
    '离线模型管理',
  ];

  static Future<void> init() async {
    // 预留初始化入口：当前版本没有账号、订阅、计费或服务器权益校验。
  }

  static bool canUse(String featureKey) => true;

  static const String statusText = '全部功能已开放';
}
