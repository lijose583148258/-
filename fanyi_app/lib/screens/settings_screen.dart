import 'package:flutter/material.dart';
import '../services/mlkit_service.dart';
import '../services/tts_service.dart';

/// 设置页面 ── 翻译引擎状态与管理
///
/// 核心作用是让用户清楚地知道当前 App 在用哪个翻译引擎，
/// 以及 ML Kit 语言模型的下载状态。
/// 透明化这些信息能显著提升用户的信任感。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  MlKitStatus? _mlKitStatus;
  bool _viTtsSupported = false;
  bool _loadingStatus = true;
  bool _downloadingModels = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    final mlStatus = await MlKitService.getStatus();
    final viTts = await TtsService.isViSupported;
    if (mounted) {
      setState(() {
        _mlKitStatus = mlStatus;
        _viTtsSupported = viTts;
        _loadingStatus = false;
      });
    }
  }

  Future<void> _triggerModelDownload() async {
    setState(() => _downloadingModels = true);
    await MlKitService.forceDownloadModels();
    await _loadStatus();
    if (mounted) setState(() => _downloadingModels = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '翻译引擎设置',
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
      body: _loadingStatus
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF677D6A)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── 三层架构说明卡片 ──────────────────────────────
                _buildArchitectureCard(),
                const SizedBox(height: 16),

                // ── 第一层：本地词典 ──────────────────────────────
                _buildEngineCard(
                  tier: '第一层',
                  title: '本地 SQLite 词典',
                  subtitle: '311 条词汇 · 完全离线 · 毫秒级响应',
                  icon: Icons.storage,
                  color: const Color(0xFF677D6A),
                  status: '✅ 始终可用',
                  statusColor: Colors.green,
                  description:
                      '覆盖高频越南语词汇、网络俚语（Gen Z 用语）和 Teencode '
                      '缩写还原。这一层在任何网络条件下都会优先尝试，有结果就直接返回，'
                      '不会向外发送任何请求。',
                ),
                const SizedBox(height: 12),

                // ── 第二层：ML Kit ────────────────────────────────
                _buildMlKitCard(),
                const SizedBox(height: 12),

                // ── 第三层：MyMemory ──────────────────────────────
                _buildEngineCard(
                  tier: '第三层',
                  title: 'MyMemory 在线翻译',
                  subtitle: '需要联网 · 免费 · 每天 5000 字符',
                  icon: Icons.cloud_outlined,
                  color: const Color(0xFF0277BD),
                  status: '🌐 需要网络',
                  statusColor: Colors.blue,
                  description:
                      '意大利 Translated 公司提供的免费翻译 API，在中国大陆无需翻墙即可访问。'
                      '当前两层都无法处理请求时（无 Google Play 服务且词库未收录该词）自动启用。'
                      '免费版每天可翻译 5000 个字符，对日常使用完全足够。',
                ),
                const SizedBox(height: 16),

                // ── 语音功能状态 ──────────────────────────────────
                _buildTtsCard(),
                const SizedBox(height: 24),

                // ── 底部提示 ──────────────────────────────────────
                const Center(
                  child: Text(
                    '翻译引擎会根据设备能力自动选择，\n无需手动切换。',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

  // ─── 三层架构流程图卡片 ───────────────────────────────────────
  Widget _buildArchitectureCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF677D6A), Color(0xFF8FA58A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔀 翻译引擎优先级',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(height: 12),
          _flowStep('本地词典', '毫秒级·离线', '→'),
          _flowStep('ML Kit', '高质量·需 GMS', '→'),
          _flowStep('MyMemory', '联网兜底', null),
          const SizedBox(height: 8),
          const Text(
            '每次翻译从第一层开始，成功则返回，失败才落到下一层。',
            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _flowStep(String name, String desc, String? arrow) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const SizedBox(width: 6),
          Text(desc,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 11)),
          if (arrow != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, color: Colors.white54, size: 14),
          ],
        ],
      ),
    );
  }

  // ─── ML Kit 专用卡片（有下载按钮和状态显示）────────────────────
  Widget _buildMlKitCard() {
    final available = _mlKitStatus?.available ?? false;
    final modelsReady = _mlKitStatus?.modelsDownloaded ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: available
              ? const Color(0xFF1565C0).withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '第二层',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Google ML Kit',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF333333)),
                ),
              ),
              Icon(
                available ? Icons.check_circle : Icons.info_outline,
                color: available ? Colors.green : Colors.grey,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '神经机器翻译 · 质量最高 · 需要 Google Play 服务',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),

          // 状态展示
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: available
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _mlKitStatus?.message ?? '检测中...',
              style: TextStyle(
                fontSize: 12,
                color: available ? const Color(0xFF2E7D32) : Colors.grey,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 说明文字
          Text(
            available
                ? modelsReady
                    ? '翻译模型已完整下载到您的手机，中↔越翻译完全在本地运行，'
                        '无需消耗任何网络流量，翻译质量与谷歌翻译网页版相同。'
                    : '已检测到 Google Play 服务！正在后台下载中↔越翻译模型（共约 60MB）。'
                        '下载完成前会临时联网翻译；完成后永久离线。'
                : '未检测到 Google Play 服务，这通常是因为您使用的是国行华为、荣耀或其他 '
                    '2020 年后出厂的无 GMS 国内手机。出国换到有 Google Play 服务的网络后，'
                    'App 会在下次启动时自动检测并启用此功能。',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF5D5D5D), height: 1.5),
          ),

          // 下载按钮（只在可用但模型未下载时显示）
          if (available && !modelsReady) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _downloadingModels ? null : _triggerModelDownload,
                icon: _downloadingModels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download, size: 18),
                label: Text(_downloadingModels ? '下载中...' : '立即下载翻译模型（约 60MB）'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 通用引擎卡片 ──────────────────────────────────────────────
  Widget _buildEngineCard({
    required String tier,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String status,
    required Color statusColor,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tier,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF333333)),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF5D5D5D), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ─── TTS 语音状态卡片 ─────────────────────────────────────────
  Widget _buildTtsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.volume_up, color: Color(0xFFD2B48C), size: 20),
              SizedBox(width: 8),
              Text(
                '语音朗读（TTS）',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF333333)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ttsRow('中文朗读', true, '调用手机系统 TTS，所有安卓手机均支持'),
          const SizedBox(height: 6),
          _ttsRow(
            '越南语朗读',
            _viTtsSupported,
            _viTtsSupported
                ? '设备已安装越南语语音包，可正常朗读'
                : '未检测到越南语语音包。\n'
                    '安装方法：设置 → 语言与输入法 → 文字转语音 → 下载越南语',
          ),
        ],
      ),
    );
  }

  Widget _ttsRow(String label, bool supported, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          supported ? Icons.check_circle : Icons.warning_amber_rounded,
          color: supported ? Colors.green : Colors.orange,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF333333))),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.grey, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
