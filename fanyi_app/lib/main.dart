import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/keyboard_helper_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/translation_screen.dart';
import 'services/app_action_service.dart';
import 'services/free_entitlement_service.dart';
import 'services/translation_service.dart';
import 'ui/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FreeEntitlementService.init();
  await AppActionService.init();
  TranslationService.warmUp();
  runApp(const FanyiTongApp());
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
        setState(() {
          _selectedIndex = 0;
        });
        break;
      case AppLaunchAction.pasteTranslate:
        setState(() {
          _selectedIndex = 0;
          _translationSeedText = null;
          _translationLaunchAction = AppLaunchAction.pasteTranslate;
          _translationRequestId = request.requestId;
        });
        break;
      case AppLaunchAction.sharedText:
        setState(() {
          _selectedIndex = 0;
          _translationSeedText = request.text;
          _translationLaunchAction = AppLaunchAction.sharedText;
          _translationRequestId = request.requestId;
        });
        break;
      case AppLaunchAction.voiceTranslate:
      case AppLaunchAction.openConversation:
        setState(() {
          _selectedIndex = 1;
        });
        break;
      case AppLaunchAction.openLearn:
        setState(() {
          _selectedIndex = 2;
        });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          Positioned.fill(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                TranslationScreen(
                  initialText: _translationSeedText,
                  launchAction: _translationLaunchAction,
                  requestId: _translationRequestId,
                ),
                const ConversationScreen(),
                const LearnScreen(),
                const CameraScreen(),
              ],
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
                      onTap: () => setState(() => _selectedIndex = index),
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
