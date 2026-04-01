import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_action_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../ui/app_theme.dart';
import 'history_screen.dart';
import 'keyboard_helper_screen.dart';

class TranslationScreen extends StatefulWidget {
  final String? initialText;
  final String? launchAction;
  final int? requestId;

  const TranslationScreen({
    super.key,
    this.initialText,
    this.launchAction,
    this.requestId,
  });

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final TextEditingController _inputController = TextEditingController();
  Timer? _debounceTimer;

  int _translationEpoch = 0;
  TranslationResult? _result;
  bool _isLoading = false;
  bool _isSpeaking = false;

  /// If set, we force a direction instead of relying on auto language detection.
  String? _directionOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyLaunchIntent();
    });
  }

  @override
  void didUpdateWidget(covariant TranslationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestId != oldWidget.requestId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyLaunchIntent();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController.dispose();
    TtsService.stop();
    super.dispose();
  }

  Future<void> _applyLaunchIntent() async {
    if (!mounted) return;

    if (widget.launchAction == AppLaunchAction.pasteTranslate) {
      final data = await Clipboard.getData('text/plain');
      final text = data?.text ?? '';
      if (text.trim().isEmpty) {
        setState(() {
          _result = null;
          _isLoading = false;
        });
        return;
      }

      _inputController.text = text;
      setState(() {});
      _translateText(text);
      return;
    }

    final text = widget.initialText?.trim() ?? '';
    if (text.isNotEmpty) {
      _inputController.text = text;
      setState(() {});
      _translateText(text);
    }
  }

  void _translateText(String text) {
    _debounceTimer?.cancel();

    if (text.trim().isEmpty) {
      _translationEpoch++;
      setState(() {
        _result = null;
        _isLoading = false;
      });
      return;
    }

    final currentEpoch = ++_translationEpoch;
    setState(() => _isLoading = true);

    _debounceTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final result = await TranslationService.translate(
          text,
          direction: _directionOverride,
        );
        if (!mounted || currentEpoch != _translationEpoch) return;

        setState(() {
          _result = result;
          _isLoading = false;
        });
      } catch (_) {
        if (!mounted || currentEpoch != _translationEpoch) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('翻译暂时失败，请稍后再试。')),
        );
      }
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

    if (!mounted) return;
    setState(() => _isSpeaking = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前设备缺少可用语音包，无法朗读。')),
      );
    }
  }

  void _copyResult() {
    if (_result == null || !_result!.hasResult) return;
    Clipboard.setData(ClipboardData(text: _result!.translated));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制译文到剪贴板。')),
    );
  }

  Future<void> _pasteToInput() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    _inputController.text = text;
    setState(() {});
    _translateText(text);
  }

  void _openKeyboardHelper() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KeyboardHelperScreen()),
    );
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TranslationHistoryScreen()),
    );
  }

  void _toggleDirectionOverride() {
    final detected = TranslationService.detectLanguage(_inputController.text);
    final autoDirection =
        detected == 'zh' ? TranslationService.zhToVi : TranslationService.viToZh;
    final current = _directionOverride ?? autoDirection;
    final next = current == TranslationService.zhToVi
        ? TranslationService.viToZh
        : TranslationService.zhToVi;

    setState(() => _directionOverride = next);
    _translateText(_inputController.text);
  }

  void _clearDirectionOverride() {
    if (_directionOverride == null) return;
    setState(() => _directionOverride = null);
    _translateText(_inputController.text);
  }

  @override
  Widget build(BuildContext context) {
    final detected = TranslationService.detectLanguage(_inputController.text);
    final autoDirection =
        detected == 'zh' ? TranslationService.zhToVi : TranslationService.viToZh;
    final resolvedDirection = _directionOverride ?? autoDirection;
    final directionLabel = resolvedDirection == TranslationService.zhToVi
        ? '中文 → 越南语'
        : '越南语 → 中文';

    return Scaffold(
      appBar: AppBar(
        title: const Text('翻译'),
        actions: [
          IconButton(
            onPressed: _openHistory,
            icon: const Icon(Icons.history_rounded),
            tooltip: '最近翻译',
          ),
          IconButton(
            onPressed: _openKeyboardHelper,
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: '聊天键盘',
          ),
          IconButton(
            onPressed:
                (_result?.hasResult == true && !_isSpeaking) ? _speakResult : null,
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              InkWell(
                onTap: _toggleDirectionOverride,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderMuted),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (_directionOverride == null ? '自动：' : '固定：') +
                              directionLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_directionOverride != null)
                        IconButton(
                          onPressed: _clearDirectionOverride,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          tooltip: '恢复自动识别',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '输入',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (_inputController.text.trim().isNotEmpty)
                            IconButton(
                              onPressed: () {
                                _inputController.clear();
                                _translateText('');
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                              tooltip: '清空',
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _inputController,
                        minLines: 5,
                        maxLines: 9,
                        onChanged: (text) {
                          setState(() {});
                          _translateText(text);
                        },
                        decoration: const InputDecoration(
                          hintText: '输入中文或越南语，结果会自动出现。',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickButton(
                            label: '粘贴',
                            icon: Icons.content_paste_rounded,
                            onTap: _pasteToInput,
                          ),
                          _QuickButton(
                            label: '聊天键盘',
                            icon: Icons.keyboard_rounded,
                            onTap: _openKeyboardHelper,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '结果',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const Spacer(),
                          if (_result != null && _result!.sourceLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.panelStrong,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppTheme.borderMuted),
                              ),
                              child: Text(
                                _result!.sourceLabel,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_isLoading)
                        const LinearProgressIndicator(
                          color: AppTheme.accent,
                          backgroundColor: AppTheme.panelStrong,
                        )
                      else
                        SelectableText(
                          _result?.hasResult == true
                              ? _result!.translated
                              : '译文会显示在这里。',
                          style: TextStyle(
                            fontSize: _result?.hasResult == true ? 22 : 14,
                            height: 1.45,
                            fontWeight: _result?.hasResult == true
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: _result?.hasResult == true
                                ? AppTheme.ink
                                : AppTheme.inkMuted,
                          ),
                        ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _QuickButton(
                            label: '复制译文',
                            icon: Icons.copy_rounded,
                            onTap: _copyResult,
                          ),
                          _QuickButton(
                            label: '朗读',
                            icon: Icons.volume_up_rounded,
                            onTap: _speakResult,
                          ),
                        ],
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
                          body: '该结果与“${_result!.hanZi}”相关，适合加入学习页。',
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
                fontWeight: FontWeight.w800,
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
                    fontWeight: FontWeight.w900,
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

