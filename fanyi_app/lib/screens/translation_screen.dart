import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../ui/app_theme.dart';
import 'keyboard_helper_screen.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputController = TextEditingController();
  TranslationResult? _result;
  bool _isLoading = false;
  bool _isSpeaking = false;
  DateTime _lastInput = DateTime.now();

  @override
  void dispose() {
    _inputController.dispose();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _translateText(String text) async {
    if (text.trim().isEmpty) {
      setState(() {
        _result = null;
        _isLoading = false;
      });
      return;
    }

    _lastInput = DateTime.now();
    final currentToken = _lastInput;

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (currentToken != _lastInput) return;

    final result = await TranslationService.translate(text);
    if (!mounted) return;

    setState(() {
      _result = result;
      _isLoading = false;
    });
  }

  Future<void> _speakResult() async {
    if (_result == null || !_result!.hasResult) return;
    setState(() => _isSpeaking = true);
    final isVietnamese = _result!.direction == TranslationService.zhToVi;
    final success = await TtsService.speak(
      _result!.translated,
      isVietnamese: isVietnamese,
    );

    if (mounted) {
      setState(() => _isSpeaking = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备未安装可用的越南语语音包。')),
        );
      }
    }
  }

  void _copyResult() {
    if (_result == null || !_result!.hasResult) return;
    Clipboard.setData(ClipboardData(text: _result!.translated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制译文到剪贴板。')),
    );
  }

  void _openKeyboardHelper() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KeyboardHelperScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detectedLanguage = TranslationService.detectLanguage(
      _inputController.text,
    );
    final directionLabel = detectedLanguage == 'zh' ? '中文 -> 越南语' : '越南语 -> 中文';

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Translate',
              style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: AppTheme.inkMuted),
            ),
            Text('翻译首页'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openKeyboardHelper,
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: '聊天键盘助手',
          ),
          IconButton(
            onPressed: _speakResult,
            icon: Icon(
              _isSpeaking ? Icons.graphic_eq_rounded : Icons.volume_up_rounded,
            ),
            tooltip: '朗读译文',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              ModemStatusBar(
                pills: [
                  const StatusPillData('MODEM READY', AppTheme.accentSoft),
                  StatusPillData(directionLabel.toUpperCase(), AppTheme.cyan),
                  StatusPillData(
                    _result?.isOnline == true ? 'ONLINE' : 'OFFLINE FIRST',
                    _result?.isOnline == true ? AppTheme.amber : AppTheme.success,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.ink,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.borderStrong),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'TEXT / OCR / CHAT INSERT',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '简单、快、可学习的中越翻译。',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '像翻译工具一样直接，像学习产品一样能沉淀词汇，还能衔接聊天键盘。',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note_rounded, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            '输入区',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.panelStrong,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              directionLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _inputController,
                        minLines: 4,
                        maxLines: 7,
                        onChanged: (text) {
                          setState(() {});
                          _translateText(text);
                        },
                        decoration: InputDecoration(
                          hintText: '输入中文或越南语，结果会自动出现。',
                          suffixIcon: _inputController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _inputController.clear();
                                    setState(() {
                                      _result = null;
                                      _isLoading = false;
                                    });
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickButton(
                            label: '粘贴',
                            icon: Icons.content_paste_rounded,
                            onTap: () async {
                              final data = await Clipboard.getData('text/plain');
                              final text = data?.text ?? '';
                              _inputController.text = text;
                              setState(() {});
                              _translateText(text);
                            },
                          ),
                          _QuickButton(
                            label: '聊天键盘',
                            icon: Icons.keyboard_command_key_rounded,
                            onTap: _openKeyboardHelper,
                          ),
                          _QuickButton(
                            label: '复制译文',
                            icon: Icons.copy_rounded,
                            onTap: _copyResult,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.memory_rounded, color: AppTheme.cyan),
                          const SizedBox(width: 8),
                          Text(
                            '结果区',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const Spacer(),
                          if (_result != null && _result!.sourceLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.panelStrong,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _result!.sourceLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_isLoading)
                        const LinearProgressIndicator(
                          color: AppTheme.accent,
                          backgroundColor: AppTheme.panelStrong,
                        )
                      else
                        Text(
                          _result?.hasResult == true
                              ? _result!.translated
                              : '译文会显示在这里。推荐把高频句子收藏到学习页，再通过聊天键盘插入到 Zalo。',
                          style: TextStyle(
                            fontSize: _result?.hasResult == true ? 24 : 14,
                            height: 1.45,
                            fontWeight: _result?.hasResult == true
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: _result?.hasResult == true
                                ? AppTheme.ink
                                : AppTheme.inkMuted,
                          ),
                        ),
                      if (_result?.normalized != null) ...[
                        const SizedBox(height: 12),
                        _InfoStrip(
                          icon: Icons.auto_fix_high_rounded,
                          title: '规范化输入',
                          body: _result!.normalized!,
                        ),
                      ],
                      if (_result?.hanZi != null) ...[
                        const SizedBox(height: 12),
                        _InfoStrip(
                          icon: Icons.auto_stories_rounded,
                          title: '汉越词根',
                          body: '这个结果和“${_result!.hanZi}”有关，适合顺手加入学习页。',
                        ),
                      ],
                      if (_result?.explanation != null) ...[
                        const SizedBox(height: 12),
                        _InfoStrip(
                          icon: Icons.bolt_rounded,
                          title: '口语说明',
                          body: _result!.explanation!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.translate_rounded,
                      title: '结果即学习',
                      body: '高频表达、俚语、汉越词根直接在结果页展开。',
                      color: AppTheme.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FeatureCard(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: '聊天辅助',
                      body: '后续从这里直连自定义输入法和截图 OCR。',
                      color: AppTheme.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.panelStrong,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.borderMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.ink),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoStrip({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.panelStrong.withValues(alpha: 0.64),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.inkMuted,
                    height: 1.45,
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.inkMuted,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
