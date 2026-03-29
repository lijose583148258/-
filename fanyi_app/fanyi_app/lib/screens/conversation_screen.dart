import 'package:flutter/material.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

/// 面对面对话翻译页面
///
/// 使用场景：两个人面对面，一个说中文，一个说越南语，
///   App 负责实时翻译并朗读给对方听。
///
/// 交互模式：PTT（Push-to-Talk，按住说话）
///   比连续监听更省电、更准确，不会误触发。
///   用户按住按钮说话，松开后自动翻译+朗读。
///
/// 布局逻辑：
///   - 屏幕上半部分：越南语一方（倒置显示，方便对面的人阅读）
///   - 屏幕下半部分：中文一方（正常显示）
///   - 中间：交换按钮（切换谁说中文谁说越南语）
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  // 对话历史记录
  final List<_ConvMessage> _messages = [];

  // 状态管理
  bool _sttAvailable = false;      // 设备是否支持语音识别
  bool _viSpeechAvailable = false; // 是否支持越南语语音识别
  bool _isListeningZh = false;     // 正在监听中文
  bool _isListeningVi = false;     // 正在监听越南语
  String _liveText = '';           // 正在识别中的实时文字（未最终确认）

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    final available = await SpeechService.initialize();
    final viSpeech = await SpeechService.isVietnameseSpeechSupported();
    if (mounted) {
      setState(() {
        _sttAvailable = available;
        _viSpeechAvailable = viSpeech;
      });
    }
  }

  // ─── PTT 按住开始录音，松开结束 ─────────────────────────
  Future<void> _startListening(bool isChinese) async {
    if (!_sttAvailable) {
      _showNoSpeechDialog();
      return;
    }
    if (isChinese) {
      setState(() { _isListeningZh = true; _liveText = ''; });
    } else {
      setState(() { _isListeningVi = true; _liveText = ''; });
    }

    final localeId = isChinese ? 'zh-CN' : 'vi-VN';
    await SpeechService.startListening(
      localeId: localeId,
      onResult: (text) {
        if (mounted) setState(() => _liveText = text);
      },
      onDone: () => _stopAndTranslate(isChinese),
    );
  }

  Future<void> _stopAndTranslate(bool isChinese) async {
    await SpeechService.stopListening();
    final text = _liveText.trim();

    if (mounted) {
      setState(() {
        _isListeningZh = false;
        _isListeningVi = false;
        _liveText = '';
      });
    }

    if (text.isEmpty) return;

    // 执行翻译
    final direction = isChinese
        ? TranslationService.zhToVi
        : TranslationService.viToZh;
    final result = await TranslationService.translate(text, direction: direction);

    if (!mounted) return;

    // 添加到对话历史
    setState(() {
      _messages.insert(0, _ConvMessage(
        original: text,
        translated: result.translated,
        isChinese: isChinese,
        sourceLabel: result.sourceLabel,
      ));
    });

    // 自动朗读译文给对方听
    await TtsService.speak(result.translated, isVietnamese: isChinese);
  }

  // ─── 手动文字输入（备用方案，不支持语音时使用）─────────
  Future<void> _manualInput(bool isChinese) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isChinese ? '输入中文' : 'Nhập tiếng Việt'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isChinese ? '请输入中文...' : 'Nhập tiếng Việt...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('翻译'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.isNotEmpty) {
      _liveText = controller.text;
      await _stopAndTranslate(isChinese);
    }
  }

  void _showNoSpeechDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语音识别不可用'),
        content: const Text(
          '当前设备不支持语音识别，或麦克风权限未开启。\n\n'
          '请检查：\n'
          '1. 是否已授予麦克风权限\n'
          '2. 手机设置 → 应用 → 翻译通 → 权限\n\n'
          '您仍可以使用手动输入按钮进行对话翻译。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF5),
      appBar: AppBar(
        title: const Text(
          '面对面翻译',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF677D6A),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // 清除对话历史
          if (_messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => setState(() => _messages.clear()),
              tooltip: '清除记录',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── 越南语一方（上半部分，倒置）────────────────────
          Expanded(
            flex: 2,
            child: RotatedBox(
              quarterTurns: 2, // 倒置，让对面的人能正向阅读
              child: _buildSpeakerPanel(
                isChinese: false,
                isListening: _isListeningVi,
                color: const Color(0xFFF0F8FF),
                icon: '🇻🇳',
                label: 'Nói tiếng Việt',
                sublabel: _viSpeechAvailable ? '按住说越南语' : '点击输入越南语',
              ),
            ),
          ),

          // ── 中间分隔条 ────────────────────────────────────
          Container(
            height: 44,
            color: const Color(0xFFE7F0DC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_vert, color: Color(0xFF677D6A), size: 20),
                const SizedBox(width: 6),
                Text(
                  _liveText.isNotEmpty
                      ? '「$_liveText」'
                      : '对话翻译 · 按住说话',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF677D6A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ── 中文一方（下半部分）──────────────────────────
          Expanded(
            flex: 2,
            child: _buildSpeakerPanel(
              isChinese: true,
              isListening: _isListeningZh,
              color: const Color(0xFFFFF8F0),
              icon: '🇨🇳',
              label: '说中文',
              sublabel: _sttAvailable ? '按住说中文' : '点击输入中文',
            ),
          ),

          // ── 对话历史记录 ──────────────────────────────────
          if (_messages.isNotEmpty)
            Container(
              height: 160,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      '对话记录（${_messages.length}条）',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessageTile(_messages[i]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─── 说话面板 ──────────────────────────────────────────
  Widget _buildSpeakerPanel({
    required bool isChinese,
    required bool isListening,
    required Color color,
    required String icon,
    required String label,
    required String sublabel,
  }) {
    return Container(
      width: double.infinity,
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF677D6A),
            ),
          ),
          const SizedBox(height: 20),
          // PTT 按钮
          GestureDetector(
            onTapDown: (_) => _sttAvailable
                ? _startListening(isChinese)
                : _manualInput(isChinese),
            onTapUp: (_) {
              if (_sttAvailable && isListening) {
                _stopAndTranslate(isChinese);
              }
            },
            onTapCancel: () {
              if (isListening) SpeechService.cancelListening();
              if (mounted) {
                setState(() {
                  _isListeningZh = false;
                  _isListeningVi = false;
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isListening ? 80 : 68,
              height: isListening ? 80 : 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isListening
                    ? const Color(0xFFE57373)
                    : const Color(0xFF677D6A),
                boxShadow: [
                  BoxShadow(
                    color: (isListening
                            ? const Color(0xFFE57373)
                            : const Color(0xFF677D6A))
                        .withOpacity(0.35),
                    blurRadius: isListening ? 20 : 10,
                    spreadRadius: isListening ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                isListening ? Icons.mic : (_sttAvailable ? Icons.mic_none : Icons.keyboard),
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isListening ? '松开完成 →' : sublabel,
            style: TextStyle(
              fontSize: 12,
              color: isListening ? const Color(0xFFE57373) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(_ConvMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.isChinese ? '🇨🇳' : '🇻🇳',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.original,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  msg.translated,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF333333),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConvMessage {
  final String original;
  final String translated;
  final bool isChinese;
  final String sourceLabel;

  _ConvMessage({
    required this.original,
    required this.translated,
    required this.isChinese,
    required this.sourceLabel,
  });
}
