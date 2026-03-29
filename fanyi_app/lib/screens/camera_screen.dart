import 'package:flutter/material.dart';

/// 拍照翻译页面（占位版本）
///
/// 功能说明：
///   拍照翻译（OCR + 翻译）需要在手机上运行文字识别模型（如 Google ML Kit）。
///   由于 ML Kit 在中国手机上不可用，这里保留功能入口，
///   后续可以接入百度 OCR API 或其他国内支持的 OCR 服务。
///
/// 临时方案：引导用户使用手机自带的文字识别功能（截图+识别），
///   然后把识别出的文字粘贴到「即时翻译」页面使用。
class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '拍照翻译',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF677D6A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(28),
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F0DC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 60,
                  color: Color(0xFF677D6A),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                '拍照翻译即将上线',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                '该功能将支持用手机摄像头扫描越南语文字（菜单、路牌、广告等），自动识别并翻译成中文。',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF777777),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 临时替代方案提示卡片
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFCC80),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('💡', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          '现在可以这样操作',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _tipStep('1', '用手机自带相机拍照'),
                    _tipStep('2', '长按图片，选择「提取文字」（华为/小米均支持）'),
                    _tipStep('3', '复制识别出的越南文字'),
                    _tipStep('4', '粘贴到「即时翻译」页面，即可翻译'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 跳转到翻译页面的按钮
              ElevatedButton.icon(
                onPressed: () {
                  // 切换到首页翻译 tab（通知父组件切换）
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('请点击底部「即时翻译」标签，粘贴识别出的文字。'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.translate),
                label: const Text('前往即时翻译'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF677D6A),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8, top: 1),
            decoration: const BoxDecoration(
              color: Color(0xFFD2B48C),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4037),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
