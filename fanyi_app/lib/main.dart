import 'package:flutter/material.dart';
import 'screens/translation_screen.dart';
import 'screens/conversation_screen.dart';
import 'screens/dictionary_screen.dart';
import 'screens/slang_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/settings_screen.dart';
import 'services/translation_service.dart';

void main() {
  // 在 Flutter 渲染引擎完全初始化后再执行原生代码
  WidgetsFlutterBinding.ensureInitialized();

  // 预热翻译服务：在后台悄悄检测 Google Play 服务是否可用。
  // 这里故意不 await，让检测与界面渲染并发进行，启动不卡顿。
  // 检测完成前翻译请求会自动跳过 ML Kit，直接用 MyMemory 兜底。
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
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD2B48C),
          surface: const Color(0xFFFFFBF5),
        ),
        // 使用系统默认字体，避免依赖 Google Fonts 网络请求
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF677D6A),
          ),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF5D5D5D)),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
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

  // IndexedStack 保持每个页面的状态，切换 tab 时不会重新加载数据
  static const List<Widget> _screens = [
    TranslationScreen(),
    ConversationScreen(),
    DictionaryScreen(),
    SlangScreen(),
    CameraScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      // 右上角设置按钮入口（通过 AppBar action 或悬浮按钮都可以）
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.small(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
              backgroundColor: const Color(0xFFD2B48C),
              tooltip: '翻译引擎设置',
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: const Color(0xFF677D6A),
        unselectedItemColor: Colors.grey.shade400,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.translate), label: '即时翻译'),
          BottomNavigationBarItem(
              icon: Icon(Icons.record_voice_over), label: '面对面'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: '深度词典'),
          BottomNavigationBarItem(
              icon: Icon(Icons.trending_up), label: '热门俚语'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: '拍照翻译'),
        ],
      ),
    );
  }
}
