import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/app_theme.dart';

class KeyboardHelperScreen extends StatefulWidget {
  const KeyboardHelperScreen({super.key});

  @override
  State<KeyboardHelperScreen> createState() => _KeyboardHelperScreenState();
}

class _KeyboardHelperScreenState extends State<KeyboardHelperScreen> {
  static const MethodChannel _channel = MethodChannel('fanyitong/ime');

  bool _enabled = false;
  bool _selected = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isImeEnabled');
      final selected = await _channel.invokeMethod<bool>('isImeSelected');
      if (mounted) {
        setState(() {
          _enabled = enabled ?? false;
          _selected = selected ?? false;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openSettings() async {
    await _channel.invokeMethod('openInputMethodSettings');
  }

  Future<void> _showPicker() async {
    await _channel.invokeMethod('showInputMethodPicker');
    await Future.delayed(const Duration(milliseconds: 500));
    _refreshStatus();
  }

  Future<void> _openAccessibilitySettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Keyboard Helper'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              const _HeroPanel(),
              const SizedBox(height: 16),
              _StatusPanel(
                loading: _loading,
                enabled: _enabled,
                selected: _selected,
              ),
              const SizedBox(height: 16),
              _ActionPanel(
                onOpenSettings: _openSettings,
                onShowPicker: _showPicker,
                onOpenAccessibilitySettings: _openAccessibilitySettings,
              ),
              const SizedBox(height: 16),
              const _HowToUsePanel(),
              const SizedBox(height: 16),
              const _NotesPanel(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.ink,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderStrong),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'IME // CHAT INSERT',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Translate Chinese into Vietnamese and insert it inside Zalo.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'This beta uses the safest chat workflow first: translate selected text, translate clipboard text, and insert the result into the active input field. The user still taps send manually.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final bool selected;

  const _StatusPanel({
    required this.loading,
    required this.enabled,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            if (loading)
              const LinearProgressIndicator(
                color: AppTheme.accent,
                backgroundColor: AppTheme.panelStrong,
              )
            else ...[
              _StatusRow(
                label: 'Keyboard enabled',
                value: enabled ? 'Yes' : 'No',
                active: enabled,
              ),
              const SizedBox(height: 10),
              _StatusRow(
                label: 'Keyboard selected now',
                value: selected ? 'Yes' : 'No',
                active: selected,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active
            ? AppTheme.accentSoft.withValues(alpha: 0.22)
            : AppTheme.panelStrong,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppTheme.accent : AppTheme.borderMuted,
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: active ? AppTheme.accent : AppTheme.inkMuted,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: active ? AppTheme.accent : AppTheme.inkMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  final VoidCallback onOpenSettings;
  final VoidCallback onShowPicker;
  final VoidCallback onOpenAccessibilitySettings;

  const _ActionPanel({
    required this.onOpenSettings,
    required this.onShowPicker,
    required this.onOpenAccessibilitySettings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enable in one minute',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded),
                label: const Text('Open system input method settings'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onShowPicker,
                icon: const Icon(Icons.keyboard_rounded),
                label: const Text('Show input method picker'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenAccessibilitySettings,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Open accessibility settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowToUsePanel extends StatelessWidget {
  const _HowToUsePanel();

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Enable the FanyiTong keyboard in Android settings.',
      'Open Zalo and switch the active keyboard to FanyiTong Keyboard.',
      'Select Chinese text in the message box, or copy Chinese text to the clipboard.',
      'Tap Translate Selection or Translate Clipboard inside the keyboard.',
      'The Vietnamese result is inserted into the current text field. Review it and send manually.',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How it works',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(steps.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.panelStrong,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.borderMuted),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        steps[index],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.ink,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _NotesPanel extends StatelessWidget {
  const _NotesPanel();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scope for this version',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This route is safer than automatic sending. The goal of the keyboard is translate-and-insert, not controlling the send action inside a chat app.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.ink,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Next upgrades can include tone presets, better candidate phrasing, and scenario-based message snippets.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.inkMuted,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
