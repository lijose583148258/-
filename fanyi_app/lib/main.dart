import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/keyboard_helper_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/translation_screen.dart';
import 'services/app_action_service.dart';
import 'services/translation_service.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FanyiTongApp());
  unawaited(_bootstrapApp());
}

Future<void> _bootstrapApp() async {
  try {
    await AppActionService.init();
  } catch (_) {
    // Launch actions are optional. Startup should not fail because of them.
  }

  TranslationService.warmUp();
}

class FanyiTongApp extends StatelessWidget {
  const FanyiTongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '翻译通',
      theme: AppTheme.theme,
      home: const MainLayout(),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  String? _translationSeedText;
  String? _translationLaunchAction;
  int _translationRequestId = 0;
  final Set<int> _loadedIndexes = <int>{0};

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.translate_rounded, label: '翻译'),
    _NavItem(icon: Icons.forum_rounded, label: '对话'),
    _NavItem(icon: Icons.school_rounded, label: '学习'),
    _NavItem(icon: Icons.camera_alt_rounded, label: '拍照'),
  ];

  @override
  void initState() {
    super.initState();
    AppActionService.pendingRequest.addListener(_handleAppAction);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAppAction();
    });
  }

  @override
  void dispose() {
    AppActionService.pendingRequest.removeListener(_handleAppAction);
    super.dispose();
  }

  void _handleAppAction() {
    final request = AppActionService.pendingRequest.value;
    if (request == null || !mounted) {
      return;
    }

    switch (request.action) {
      case AppLaunchAction.openTranslate:
        _activateTab(0);
        break;
      case AppLaunchAction.pasteTranslate:
        setState(() {
          _selectedIndex = 0;
          _loadedIndexes.add(0);
          _translationSeedText = null;
          _translationLaunchAction = AppLaunchAction.pasteTranslate;
          _translationRequestId = request.requestId;
        });
        break;
      case AppLaunchAction.sharedText:
        setState(() {
          _selectedIndex = 0;
          _loadedIndexes.add(0);
          _translationSeedText = request.text;
          _translationLaunchAction = AppLaunchAction.sharedText;
          _translationRequestId = request.requestId;
        });
        break;
      case AppLaunchAction.voiceTranslate:
      case AppLaunchAction.openConversation:
        _activateTab(1);
        break;
      case AppLaunchAction.openLearn:
        _activateTab(2);
        break;
      case AppLaunchAction.openKeyboard:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const KeyboardHelperScreen()),
          );
        });
        break;
    }

    AppActionService.clearPending();
  }

  void _activateTab(int index) {
    setState(() {
      _selectedIndex = index;
      _loadedIndexes.add(index);
    });
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return TranslationScreen(
          initialText: _translationSeedText,
          launchAction: _translationLaunchAction,
          requestId: _translationRequestId,
        );
      case 1:
        return const ConversationScreen();
      case 2:
        return const LearnScreen();
      case 3:
        return const CameraScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: List<Widget>.generate(_items.length, (index) {
                if (!_loadedIndexes.contains(index)) {
                  return const SizedBox.shrink();
                }
                return _buildTab(index);
              }),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        },
        backgroundColor: AppTheme.accent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.tune_rounded),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.shell,
          border: Border(
            top: BorderSide(color: AppTheme.borderStrong, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(
              children: List.generate(_items.length, (index) {
                final item = _items[index];
                final selected = index == _selectedIndex;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _activateTab(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.panelStrong
                              : Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? AppTheme.accent
                                : AppTheme.borderMuted,
                          ),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(
                                    color: AppTheme.shadow,
                                    blurRadius: 14,
                                    offset: Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 20,
                              color: selected
                                  ? AppTheme.ink
                                  : AppTheme.inkMuted,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? AppTheme.ink
                                    : AppTheme.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}
