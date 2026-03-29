import 'package:flutter/material.dart';

import '../services/speech_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';
import '../ui/app_theme.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final List<_ConversationEntry> _messages = [];

  bool _speechAvailable = false;
  bool _vietnameseSpeechAvailable = false;
  bool _isListeningChinese = false;
  bool _isListeningVietnamese = false;
  String _liveText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await SpeechService.initialize();
    final viAvailable = await SpeechService.isVietnameseSpeechSupported();
    if (!mounted) return;
    setState(() {
      _speechAvailable = available;
      _vietnameseSpeechAvailable = viAvailable;
    });
  }

  Future<void> _startListening(bool chineseSource) async {
    if (!_speechAvailable) {
      _showSpeechUnavailable();
      return;
    }

    setState(() {
      _liveText = '';
      _isListeningChinese = chineseSource;
      _isListeningVietnamese = !chineseSource;
    });

    await SpeechService.startListening(
      localeId: chineseSource ? 'zh-CN' : 'vi-VN',
      onResult: (text) {
        if (mounted) {
          setState(() => _liveText = text);
        }
      },
      onDone: () => _finishListening(chineseSource),
    );
  }

  Future<void> _finishListening(bool chineseSource) async {
    await SpeechService.stopListening();
    final original = _liveText.trim();

    if (mounted) {
      setState(() {
        _isListeningChinese = false;
        _isListeningVietnamese = false;
        _liveText = '';
      });
    }

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

    await TtsService.speak(
      result.translated,
      isVietnamese: chineseSource,
    );
  }

  Future<void> _manualInput(bool chineseSource) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(chineseSource ? '输入中文' : '输入越南语'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '输入后会直接翻译并朗读。',
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

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      _liveText = controller.text;
      await _finishListening(chineseSource);
    }
  }

  void _showSpeechUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('当前设备无法使用语音识别，请改用手动输入。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'DUAL TALK',
              style: TextStyle(fontSize: 11, letterSpacing: 1.1, color: AppTheme.inkMuted),
            ),
            Text('对话翻译'),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty)
            IconButton(
              onPressed: () => setState(() => _messages.clear()),
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
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: ModemStatusBar(
                  pills: [
                    const StatusPillData('PTT MODE', AppTheme.accentSoft),
                    StatusPillData(
                      _speechAvailable ? 'MIC READY' : 'MANUAL ONLY',
                      _speechAvailable ? AppTheme.success : AppTheme.amber,
                    ),
                    StatusPillData(
                      _vietnameseSpeechAvailable ? 'VI STT ON' : 'VI STT LIMITED',
                      _vietnameseSpeechAvailable ? AppTheme.cyan : AppTheme.amber,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppTheme.ink,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.borderStrong),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '面对面说话，App 负责转译与朗读。',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _liveText.isEmpty
                            ? '按住按钮说话，松开后自动翻译。语音不可用时可直接手动输入。'
                            : '识别中: $_liveText',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
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
                        child: _ActionPad(
                          title: '中文说话方',
                          subtitle: _speechAvailable ? '按住说中文' : '手动输入中文',
                          accent: AppTheme.accent,
                          active: _isListeningChinese,
                          icon: _speechAvailable ? Icons.mic_rounded : Icons.keyboard_rounded,
                          onTapDown: (_) {
                            if (_speechAvailable) {
                              _startListening(true);
                            } else {
                              _manualInput(true);
                            }
                          },
                          onTapUp: (_) {
                            if (_speechAvailable && _isListeningChinese) {
                              _finishListening(true);
                            }
                          },
                          onTapCancel: () async {
                            if (_isListeningChinese) {
                              await SpeechService.cancelListening();
                              if (mounted) {
                                setState(() => _isListeningChinese = false);
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionPad(
                          title: '越南语说话方',
                          subtitle: _speechAvailable ? '按住说越南语' : '手动输入越南语',
                          accent: AppTheme.cyan,
                          active: _isListeningVietnamese,
                          icon: _speechAvailable ? Icons.record_voice_over_rounded : Icons.keyboard_rounded,
                          onTapDown: (_) {
                            if (_speechAvailable) {
                              _startListening(false);
                            } else {
                              _manualInput(false);
                            }
                          },
                          onTapUp: (_) {
                            if (_speechAvailable && _isListeningVietnamese) {
                              _finishListening(false);
                            }
                          },
                          onTapCancel: () async {
                            if (_isListeningVietnamese) {
                              await SpeechService.cancelListening();
                              if (mounted) {
                                setState(() => _isListeningVietnamese = false);
                              }
                            }
                          },
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

class _ActionPad extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final bool active;
  final IconData icon;
  final GestureTapDownCallback onTapDown;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onTapCancel;

  const _ActionPad({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.active,
    required this.icon,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onTapCancel: onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: active ? accent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? accent : AppTheme.borderMuted, width: active ? 1.4 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: active ? accent : AppTheme.ink,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
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
              active ? '松手翻译' : subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: active ? accent : AppTheme.inkMuted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: entry.chineseSource
                        ? AppTheme.accentSoft.withValues(alpha: 0.24)
                        : AppTheme.cyan.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    entry.chineseSource ? '中文 -> 越南语' : '越南语 -> 中文',
                    style: TextStyle(
                      fontSize: 11,
                      color: entry.chineseSource ? AppTheme.accent : AppTheme.cyan,
                      fontWeight: FontWeight.w700,
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
                fontWeight: FontWeight.w800,
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
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: const [
                Icon(Icons.multitrack_audio_rounded, size: 44, color: AppTheme.inkMuted),
                SizedBox(height: 14),
                Text(
                  '这里会按时间倒序保存刚刚的对话。',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '先试着按住中文或越南语按钮说一句话，系统会自动翻译并朗读给对方听。',
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
