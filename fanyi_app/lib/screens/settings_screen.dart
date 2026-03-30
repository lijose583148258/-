import 'package:flutter/material.dart';

import '../services/local_db_service.dart';
import '../services/mlkit_service.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  MlKitStatus? _mlKitStatus;
  AppStorageStats? _storageStats;
  bool _viTtsSupported = false;
  bool _loading = true;
  bool _downloadingModels = false;
  bool _clearingHistory = false;
  bool _clearingModels = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final results = await Future.wait<dynamic>([
      MlKitService.getStatus(),
      TtsService.isViSupported,
      LocalDbService.getStorageStats(),
    ]);

    if (!mounted) return;
    setState(() {
      _mlKitStatus = results[0] as MlKitStatus;
      _viTtsSupported = results[1] as bool;
      _storageStats = results[2] as AppStorageStats;
      _loading = false;
    });
  }

  Future<void> _triggerModelDownload() async {
    setState(() => _downloadingModels = true);
    await MlKitService.forceDownloadModels();
    await _loadStatus();
    if (mounted) setState(() => _downloadingModels = false);
  }

  Future<void> _clearTranslationHistory() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清理翻译历史'),
            content: const Text('这会删除本地最近翻译记录，但不会删除词典或离线模型。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清理'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _clearingHistory = true);
    await LocalDbService.clearTranslationHistory();
    await _loadStatus();
    if (mounted) setState(() => _clearingHistory = false);
  }

  Future<void> _clearMlKitCache() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('清理离线模型'),
            content: const Text('这会移除 ML Kit 离线翻译模型，之后可重新下载。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('清理'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _clearingModels = true);
    await MlKitService.clearDownloadedModels();
    await _loadStatus();
    if (mounted) setState(() => _clearingModels = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '翻译通设置',
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF677D6A)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildArchitectureCard(),
                const SizedBox(height: 16),
                _buildEngineCard(
                  tier: '第一层',
                  title: '本地 SQLite 词典',
                  subtitle: '离线优先 · 毫秒级响应 · 自动限额',
                  icon: Icons.storage,
                  color: const Color(0xFF677D6A),
                  status: '始终可用',
                  statusColor: Colors.green,
                  description:
                      '词典、俚语和规范化规则都在本地查询，不依赖网络。翻译历史自动限制为最近 200 条，避免真机长期测试时占用过大。',
                ),
                const SizedBox(height: 12),
                _buildMlKitCard(),
                const SizedBox(height: 12),
                _buildEngineCard(
                  tier: '第三层',
                  title: 'MyMemory 在线翻译',
                  subtitle: '联网兜底 · 免费 · 作为最后一层回退',
                  icon: Icons.cloud_outlined,
                  color: const Color(0xFF0277BD),
                  status: '需要网络',
                  statusColor: Colors.blue,
                  description:
                      '当本地词典和 ML Kit 都无法处理时，才会向外部翻译服务请求结果。它只作为兜底，不影响离线主流程。',
                ),
                const SizedBox(height: 16),
                _buildTtsCard(),
                const SizedBox(height: 16),
                _buildStorageCard(),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    '翻译引擎会根据设备能力自动选择。历史记录会自动保留最近 200 条，需要时可在本页一键清理。',
                    style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }

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
            '翻译引擎优先级',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          _flowStep('本地词典', '离线优先', '→'),
          _flowStep('ML Kit', '高质量本地翻译', '→'),
          _flowStep('MyMemory', '联网兜底', null),
          const SizedBox(height: 8),
          const Text(
            '每次翻译都从第一层开始，成功就直接返回，失败才进入下一层。',
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
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          if (arrow != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward, color: Colors.white54, size: 14),
          ],
        ],
      ),
    );
  }

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
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Google ML Kit',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
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
            '本地神经机器翻译。若模型已下载，它不会消耗网络流量。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 10),
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
          Text(
            available
                ? modelsReady
                    ? '模型已就绪，适合真机长期测试。'
                    : '已检测到 Google Play 服务，模型正在后台准备。'
                : '未检测到 Google Play 服务，设备会自动走本地词典和联网兜底。',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5D5D5D),
              height: 1.5,
            ),
          ),
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
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download, size: 18),
                label: Text(_downloadingModels ? '下载中...' : '立即下载离线模型'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tier,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF333333),
                  ),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
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
              fontSize: 12,
              color: Color(0xFF5D5D5D),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

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
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ttsRow('中文朗读', true, '调用手机系统 TTS。'),
          const SizedBox(height: 6),
          _ttsRow(
            '越南语朗读',
            _viTtsSupported,
            _viTtsSupported
                ? '设备已支持越南语朗读。'
                : '未检测到越南语语音包，可在系统里安装。',
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
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                desc,
                style: const TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStorageCard() {
    final stats = _storageStats;
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
              Icon(Icons.storage_rounded, color: Color(0xFF677D6A), size: 20),
              SizedBox(width: 8),
              Text(
                '存储控制',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            stats == null
                ? '正在统计本地占用...'
                : '翻译历史：${stats.historyCount}/${stats.maxHistory} 条  ·  '
                    '词典文件：${_formatBytes(stats.dictionaryBytes)}  ·  '
                    'App 数据：${_formatBytes(stats.appDbBytes)}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF5D5D5D),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _clearingHistory ? null : _clearTranslationHistory,
                icon: _clearingHistory
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline, size: 18),
                label: const Text('清理翻译历史'),
              ),
              ElevatedButton.icon(
                onPressed: _clearingModels ? null : _clearMlKitCache,
                icon: _clearingModels
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_off_outlined, size: 18),
                label: const Text('清理离线模型'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
