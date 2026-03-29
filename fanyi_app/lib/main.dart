import 'package:flutter/material.dart';

import 'screens/camera_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/learn_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/translation_screen.dart';
import 'services/translation_service.dart';
import 'ui/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

  static const List<Widget> _screens = [
    TranslationScreen(),
    ConversationScreen(),
    LearnScreen(),
    CameraScreen(),
  ];

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.translate_rounded, label: '翻译'),
    _NavItem(icon: Icons.forum_rounded, label: '对话'),
    _NavItem(icon: Icons.school_rounded, label: '学习'),
    _NavItem(icon: Icons.camera_alt_rounded, label: '拍照'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: AppThemeShell()),
          Positioned.fill(
            child: IndexedStack(index: _selectedIndex, children: _screens),
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
