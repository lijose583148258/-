import 'dart:async';

import 'package:flutter/material.dart';

import '../services/device_compatibility_service.dart';
import '../services/speech_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../ui/app_theme.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with WidgetsBindingObserver {
  final List<_ConversationEntry> _messages = [];

  bool _speechAvailable = false;
  bool _vietnameseSpeechAvailable = false;

  bool _isListening = false;
  bool _isFinalizing = false;
  bool _listeningChineseSource = true;
  String _liveText = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSpeech(requestPermission: true);
  }

  Future<void> _initSpeech({bool requestPermission = false}) async {
    final available = requestPermission
        ? await SpeechService.initialize()
        : await SpeechService.refreshAvailability();
    final viAvailable = available
        ? await SpeechService.isVietnameseSpeechSupported()
        : false;
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      _vietnameseSpeechAvailable = viAvailable;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initSpeech();
    }
  }

  Future<void> _retrySpeech() async {
    if (_isFinalizing) return;
    final available = await SpeechService.initialize(forceRetry: true);
    final viAvailable = available
        ? await SpeechService.isVietnameseSpeechSupported()
        : false;
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      _vietnameseSpeechAvailable = viAvailable;
    });
    if (!available) _showSpeechUnavailable();
  }

  Future<void> _startListening(bool chineseSource) async {
    if (_isFinalizing) return;
    if (!_speechAvailable) {
      _showSpeechUnavailable();
      return;
    }

    setState(() {
      _isListening = true;
      _listeningChineseSource = chineseSource;
      _liveText = '';
    });

    final started = await SpeechService.startListening(
      localeId: chineseSource ? 'zh-CN' : 'vi-VN',
      onResult: (text) {
        if (mounted &&
            _isListening &&
            _listeningChineseSource == chineseSource) {
          setState(() => _liveText = text);
        }
      },
      onDone: () => unawaited(_stopAndTranslate(chineseSource)),
    );
    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _liveText = '';
      });
      _showSpeechUnavailable();
    }
  }

  Future<void> _stopAndTranslate(bool chineseSource) async {
    if (_isFinalizing) return;
    _isFinalizing = true;
    final original = _liveText.trim();

    if (mounted) {
      setState(() {
        _isListening = false;
        _liveText = '';
      });
    }

    try {
      await SpeechService.stopListening();
      if (original.isEmpty) return;

      final result = await TranslationService.translate(
        original,
        direction: chineseSource
            ? TranslationService.zhToVi
            : TranslationService.viToZh,
      );

      if (!mounted) return;

      setState(() {
        _messages.insert(
          0,
          _ConversationEntry(
            original: original,
            translated: result.translated,
            chineseSource: chineseSource,
            sourceLabel: result.sourceLabel,
          ),
        );
      });

      await TtsService.speak(result.translated, isVietnamese: chineseSource);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本次对话翻译失败，请改用手动输入重试。')),
      );
    } finally {
      _isFinalizing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _manualInput(bool chineseSource) async {
    if (_isFinalizing) return;
    final controller = TextEditingController();
    bool? confirmed;
    String text = '';
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(chineseSource ? '输入中文' : '输入越南语'),
            content: TextField(
              controller: controller,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(hintText: '输入后会直接翻译并朗读。'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('翻译'),
              ),
            ],
          );
        },
      );
      text = controller.text.trim();
    } finally {
      controller.dispose();
    }

    if (confirmed == true && text.isNotEmpty && mounted) {
      setState(() => _liveText = text);
      await _stopAndTranslate(chineseSource);
    }
  }

  void _showSpeechUnavailable() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('当前设备无法使用语音识别，请改用手动输入。'),
        action: SnackBarAction(
          label: '系统设置',
          onPressed: () {
            DeviceCompatibilityService.openAppDetailsSettings().ignore();
          },
        ),
      ),
    );
  }

  Future<void> _onInputPressed(bool chineseSource) async {
    if (_isFinalizing) return;
    if (!_speechAvailable) {
      await _manualInput(chineseSource);
      return;
    }

    if (_isListening) {
      // Tapping the same side stops and translates. Tapping the other side switches.
      if (_listeningChineseSource == chineseSource) {
        await _stopAndTranslate(chineseSource);
      } else {
        await SpeechService.stopListening();
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _liveText = '';
        });
        await _startListening(chineseSource);
      }
      return;
    }

    await _startListening(chineseSource);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SpeechService.cancelListening().ignore();
    TtsService.stop().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _isFinalizing
        ? '正在处理翻译…'
        : !_speechAvailable
        ? '语音不可用，改用手动输入。'
        : _isListening
        ? (_listeningChineseSource ? '正在听中文：$_liveText' : '正在听越南语：$_liveText')
        : '点一下开始说话，再点一下停止并翻译。';

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话翻译'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _isFinalizing
                  ? null
                  : () => setState(() => _messages.clear()),
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: '清空记录',
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderMuted),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.record_voice_over_rounded,
                        size: 18,
                        color: AppTheme.ink,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_isFinalizing)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_speechAvailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                (_vietnameseSpeechAvailable
                                        ? AppTheme.cyan
                                        : AppTheme.amber)
                                    .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.borderMuted),
                          ),
                          child: Text(
                            _vietnameseSpeechAvailable
                                ? 'VI STT OK'
                                : 'VI STT LIMITED',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                              letterSpacing: 0.3,
                            ),
                          ),
                        )
                      else
                        TextButton.icon(
                          onPressed: _retrySpeech,
                          icon: const Icon(
                            Icons.settings_voice_rounded,
                            size: 16,
                          ),
                          label: const Text('检查权限'),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _messages.isEmpty
                    ? const _ConversationEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _ConversationCard(entry: _messages[index]);
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DualActionButton(
                          title: '中文',
                          subtitle: _speechAvailable ? '开始说 / 停止翻译' : '手动输入',
                          color: AppTheme.accent,
                          active: _isListening && _listeningChineseSource,
                          icon: _speechAvailable
                              ? (_isListening && _listeningChineseSource
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded)
                              : Icons.keyboard_rounded,
                          onPressed: _isFinalizing
                              ? null
                              : () => _onInputPressed(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DualActionButton(
                          title: '越南语',
                          subtitle: _speechAvailable ? '开始说 / 停止翻译' : '手动输入',
                          color: AppTheme.cyan,
                          active: _isListening && !_listeningChineseSource,
                          icon: _speechAvailable
                              ? (_isListening && !_listeningChineseSource
                                    ? Icons.stop_rounded
                                    : Icons.mic_rounded)
                              : Icons.keyboard_rounded,
                          onPressed: _isFinalizing
                              ? null
                              : () => _onInputPressed(false),
                        ),
                      ),
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

class _DualActionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final bool active;
  final IconData icon;
  final VoidCallback? onPressed;

  const _DualActionButton({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.active,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: active ? color : Colors.white.withValues(alpha: 0.88),
        foregroundColor: active ? Colors.white : AppTheme.ink,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: active ? color : AppTheme.borderMuted),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white.withValues(alpha: 0.18)
                  : color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: active ? Colors.white : color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? Colors.white70 : AppTheme.inkMuted,
                    fontWeight: FontWeight.w600,
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

class _ConversationCard extends StatelessWidget {
  final _ConversationEntry entry;

  const _ConversationCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final pillColor = entry.chineseSource ? AppTheme.accentSoft : AppTheme.cyan;
    final pillText = entry.chineseSource ? '中文 → 越南语' : '越南语 → 中文';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.borderMuted),
                  ),
                  child: Text(
                    pillText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  entry.sourceLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              entry.original,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.inkMuted,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.translated,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: const [
        Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 44,
                  color: AppTheme.inkMuted,
                ),
                SizedBox(height: 12),
                Text(
                  '这里会保存最近的对话翻译。',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '点中文或越南语开始说话，再点一次停止并翻译。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.inkMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversationEntry {
  final String original;
  final String translated;
  final bool chineseSource;
  final String sourceLabel;

  const _ConversationEntry({
    required this.original,
    required this.translated,
    required this.chineseSource,
    required this.sourceLabel,
  });
}
