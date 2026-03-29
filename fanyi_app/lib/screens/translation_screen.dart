import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

/// 即时翻译页面
///
/// 功能说明：
///   1. 自动检测输入语言（中文 ↔ 越南语），无需手动切换
///   2. 优先查本地词典（离线、毫秒级），查不到时自动调在线 API
///   3. 右上角语音朗读按钮（调用手机系统 TTS）
///   4. 长按译文可复制到剪贴板
///   5. 显示翻译来源标签，让用户清楚知道结果从哪里来
class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  TranslationResult? _result;
  bool _isLoading = false;
  bool _isSpeaking = false;

  // 防抖计时器：用户停止输入 600ms 后才触发翻译，避免每按一个键都请求 API
  DateTime _lastInput = DateTime.now();

  @override
  void dispose() {
    _inputCtrl.dispose();
    TtsService.stop();
    super.dispose();
  }

  // ─── 翻译逻辑 ─────────────────────────────────────────
  Future<void> _onTextChanged(String text) async {
    if (text.trim().isEmpty) {
      setState(() => _result = null);
      return;
    }

    _lastInput = DateTime.now();
    final capturedTime = _lastInput;

    setState(() => _isLoading = true);

    // 等待 600ms 防抖
    await Future.delayed(const Duration(milliseconds: 600));

    // 如果在等待期间用户又输入了新内容，就放弃这次请求
    if (capturedTime != _lastInput) return;

    final result = await TranslationService.translate(text);

    if (mounted) {
      setState(() {
        _result = result;
        _isLoading = false;
      });
    }
  }

  // ─── 朗读译文 ─────────────────────────────────────────
  Future<void> _speak() async {
    if (_result == null || !_result!.hasResult) return;
    setState(() => _isSpeaking = true);

    // 判断译文是越南语还是中文
    final isVi = _result!.direction == TranslationService.zhToVi;
    final success = await TtsService.speak(
      _result!.translated,
      isVietnamese: isVi,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('当前设备未安装越南语语音包，请在手机设置中下载。'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) setState(() => _isSpeaking = false);
  }

  // ─── 复制译文 ─────────────────────────────────────────
  void _copyResult() {
    if (_result == null) return;
    Clipboard.setData(ClipboardData(text: _result!.translated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ 译文已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  // ─── 界面构建 ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '翻译通',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            color: Color(0xFF677D6A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 朗读按钮
          IconButton(
            icon: Icon(
              _isSpeaking ? Icons.volume_up : Icons.volume_up_outlined,
              color: _isSpeaking
                  ? const Color(0xFF677D6A)
                  : Colors.grey.shade400,
            ),
            onPressed: _speak,
            tooltip: '朗读译文',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 语言方向提示
            _buildDirectionHint(),
            const SizedBox(height: 12),
            // 输入框
            _buildInputArea(),
            const SizedBox(height: 16),
            // 翻译结果
            _buildResultArea(),
            // 来源标签 + 汉越词提示
            if (_result != null && _result!.hasResult) ...[
              const SizedBox(height: 10),
              _buildSourceBadge(),
            ],
            // 俚语详解卡片
            if (_result != null && _result!.isSlang) ...[
              const SizedBox(height: 10),
              _buildSlangCard(),
            ],
            // 汉越字根提示
            if (_result != null && _result!.hanZi != null) ...[
              const SizedBox(height: 10),
              _buildHanZiTip(),
            ],
            const SizedBox(height: 30),
            // 底部快捷按钮
            _buildShortcutRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionHint() {
    final lang = TranslationService.detectLanguage(_inputCtrl.text);
    final hint = lang == 'zh' ? '中文 → 越南语' : '越南语 → 中文';
    final icon = lang == 'zh' ? '🇨🇳→🇻🇳' : '🇻🇳→🇨🇳';
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF677D6A),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        const Text(
          '自动检测语言',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _inputCtrl,
        maxLines: 5,
        onChanged: _onTextChanged,
        style: const TextStyle(fontSize: 16, color: Color(0xFF333333)),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
          hintText: '输入中文或越南语，自动识别并翻译...',
          hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 14),
          suffixIcon: _inputCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _inputCtrl.clear();
                    setState(() => _result = null);
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildResultArea() {
    return GestureDetector(
      onLongPress: _copyResult, // 长按复制
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EFE5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '译文',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (_result != null && _result!.hasResult)
                  GestureDetector(
                    onTap: _copyResult,
                    child: const Icon(
                      Icons.copy,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF677D6A),
                ),
              )
            else
              Text(
                _result?.hasResult == true
                    ? _result!.translated
                    : '在上方输入文字，翻译结果将显示在这里。',
                style: TextStyle(
                  fontSize: _result?.hasResult == true ? 22 : 14,
                  fontWeight: _result?.hasResult == true
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _result?.hasResult == true
                      ? const Color(0xFF333333)
                      : Colors.grey,
                  height: 1.5,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceBadge() {
    final isOnline = _result!.isOnline;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isOnline
                ? const Color(0xFFE3F2FD)
                : const Color(0xFFE7F0DC),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _result!.sourceLabel,
            style: TextStyle(
              fontSize: 11,
              color: isOnline
                  ? Colors.blue.shade700
                  : const Color(0xFF677D6A),
            ),
          ),
        ),
        // 如果 Teencode 被规范化，显示提示
        if (_result!.normalized != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '已还原缩写：${_result!.normalized}',
              style: const TextStyle(fontSize: 11, color: Colors.orange),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSlangCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCC80), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💬', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _result!.explanation ?? '',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5D4037),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHanZiTip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('🈶', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '汉越词提示：这个词源自汉字「${_result!.hanZi}」，用中文直觉就能记住发音！',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _shortcutItem(Icons.history, '历史记录', () {}),
        _shortcutItem(Icons.collections_bookmark, '生词本', () {}),
        _shortcutItem(Icons.quiz, '每日一句', () {}),
      ],
    );
  }

  Widget _shortcutItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFD2B48C), size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
