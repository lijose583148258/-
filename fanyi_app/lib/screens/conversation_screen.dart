import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SpeechService.cancelListening().ignore();
    TtsService.stop().ignore();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _initSpeech(requestPermission: false);
    }
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

  Future<void> _retrySpeech() async {
    if (_isFinalizing) return;
    final available = await SpeechService.initialize(
      requestPermission: true,
      forceRetry: true,
    );
    final viAvailable = available
        ? await SpeechService.isVietnameseSpeechSupported()
        : false;
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      _vietnameseSpeechAvailable = viAvailable;
    });
    if (!available) {
      await openAppSettings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请在系统应用设置中开启“麦克风”权限，开启后返回即可使用语音。'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _startListening(bool chineseSource) async {
    if (_isFinalizing) return;
    if (!_speechAvailable) {
      await _manualInput(chineseSource);
      return;
    }

    if (!chineseSource && !_vietnameseSpeechAvailable) {
      await _manualInput(chineseSource);
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
        if (mounted && _isListening && _listeningChineseSource == chineseSource) {
          setState(() => _liveText = text);
        }
      },
      onDone: () => unawaited(_stopAndTranslate(chineseSource)),
      onError: (error) {
        debugPrint('STT error callback: $error');
        if (mounted && _isListening && _listeningChineseSource == chineseSource) {
          if (_liveText.trim().isNotEmpty) {
            unawaited(_stopAndTranslate(chineseSource));
          } else {
            setState(() {
              _isListening = false;
              _liveText = '';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('未识别到语音，请靠近麦克风重试。')),
            );
          }
        }
      },
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
    await SpeechService.stopListening();
    final original = _liveText.trim();

    if (mounted) {
      setState(() {
        _isListening = false;
        _liveText = '';
      });
    }

    if (original.isEmpty) {
      _isFinalizing = false;
      if (mounted) setState(() {});
      return;
    }

    try {
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

      await TtsService.speak(
        result.translated,
        isVietnamese: chineseSource,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('翻译失败，请检查网络后重试。')),
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
              decoration: InputDecoration(
                hintText: chineseSource
                    ? '输入中文后直接翻译为越南语并朗读。'
                    : '输入越南语后直接翻译为中文并朗读。',
              ),
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
        content: const Text('当前设备无法使用语音识别，请检查权限或改用手动输入。'),
        action: SnackBarAction(
          label: '检查权限',
          onPressed: _retrySpeech,
        ),
      ),
    );
  }

  Future<void> _onInputPressed(bool chineseSource) async {
    if (_isFinalizing) return;

    if (!chineseSource && !_vietnameseSpeechAvailable) {
      await _manualInput(false);
      return;
    }

    if (!_speechAvailable) {
      await _manualInput(chineseSource);
      return;
    }

    if (_isListening) {
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
  Widget build(BuildContext context) {
    final statusText = _isFinalizing
        ? '正在处理翻译并朗读…'
        : !_speechAvailable
            ? '麦克风权限未开启或语音服务不可用，支持手动输入'
            : _isListening
                ? (_listeningChineseSource
                    ? '正在听中文：$_liveText'
                    : '正在听越南语：$_liveText')
                : '面对面互译：点中文说译越语，点越语说译中文';

    return Scaffold(
      appBar: AppBar(
        title: const Text('面对面翻译'),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: _isFinalizing ? null : () => setState(() => _messages.clear()),
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
                            color: (_vietnameseSpeechAvailable
                                    ? AppTheme.cyan
                                    : AppTheme.amber)
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppTheme.borderMuted),
                          ),
                          child: Text(
                            _vietnameseSpeechAvailable ? '越语语音就绪' : '越语建议键入',
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
                          subtitle: _speechAvailable
                              ? (_isListening && _listeningChineseSource
                                  ? '点击停止并翻译'
                                  : '点按开始说话')
                              : '手动输入中文',
                          color: AppTheme.accent,
                          active: _isListening && _listeningChineseSource,
                          icon: _speechAvailable
                              ? (_isListening && _listeningChineseSource
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded)
                              : Icons.keyboard_rounded,
                          onPressed: _isFinalizing ? null : () => _onInputPressed(true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DualActionButton(
                          title: '越南语',
                          subtitle: (_speechAvailable && _vietnameseSpeechAvailable)
                              ? (_isListening && !_listeningChineseSource
                                  ? '点击停止并翻译'
                                  : '点按开始说话')
                              : '手动输入越南语',
                          color: AppTheme.cyan,
                          active: _isListening && !_listeningChineseSource,
                          icon: (_speechAvailable && _vietnameseSpeechAvailable)
                              ? (_isListening && !_listeningChineseSource
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded)
                              : Icons.keyboard_rounded,
                          onPressed: _isFinalizing ? null : () => _onInputPressed(false),
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
            child: Icon(
              icon,
              color: active ? Colors.white : color,
              size: 22,
            ),
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
                    fontSize: 10,
                    color: active ? Colors.white70 : AppTheme.inkMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

  const _ConversationCard({
    required this.entry,
  });

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                IconButton(
                  icon: const Icon(Icons.volume_up_rounded, size: 20),
                  color: AppTheme.inkMuted,
                  tooltip: '朗读译文',
                  onPressed: () {
                    TtsService.speak(
                      entry.translated,
                      isVietnamese: entry.chineseSource,
                    ).ignore();
                  },
                ),
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
            const SizedBox(height: 8),
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
                fontSize: 18,
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
                  '面对面对话翻译',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '一人说中文、一人说越南语；\nApp 自动识别语音、互译并语音朗读，也可随时打字输入。',
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
