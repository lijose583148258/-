import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/screens/conversation_screen.dart';
import 'package:fanyi_tong/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService unit tests', () {
    test('resolveLocaleId handles empty/fallback locale gracefully', () async {
      // In sandbox/test environment with no STT engine running,
      // it should return the requested locale safely without crashing.
      final zh = await SpeechService.resolveLocaleId('zh-CN');
      expect(zh, equals('zh-CN'));

      final vi = await SpeechService.resolveLocaleId('vi-VN');
      expect(vi, equals('vi-VN'));
    });

    test('SpeechService availability and listening initial flags', () {
      expect(SpeechService.isListening, isFalse);
    });

    test('SpeechService supported locales safely returns empty list without native engine', () async {
      final locales = await SpeechService.getSupportedLocales();
      expect(locales, isA<List<String>>());
    });
  });

  group('ConversationScreen widget and interaction tests', () {
    testWidgets('renders conversation screen, status card, and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Title
      expect(find.text('面对面翻译'), findsOneWidget);
      // Chinese and Vietnamese action buttons
      expect(find.text('中文'), findsOneWidget);
      expect(find.text('越南语'), findsOneWidget);
      // Text input shortcut button in AppBar
      expect(find.byIcon(Icons.keyboard_outlined), findsOneWidget);
      // Empty state prompt
      expect(find.text('面对面对话翻译'), findsOneWidget);
    });

    testWidgets('tapping manual input button opens dialog and can cancel', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Tap manual input shortcut in AppBar
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('输入中文'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('翻译'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.text('输入中文'), findsNothing);
    });

    testWidgets('submitting text via manual input translates and adds message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Tap manual input in AppBar
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();

      // Enter text
      await tester.enterText(find.byType(TextField), '你好');
      await tester.pumpAndSettle();

      // Tap translate
      await tester.tap(find.text('翻译'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));

      // Verify conversation message appears
      expect(find.text('你好'), findsWidgets);
    });

    testWidgets('tapping bottom button when speech is unavailable gracefully prompts fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConversationScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));

      // Tap the Chinese button at the bottom
      await tester.tap(find.text('中文'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Dialog for manual input automatically opens when STT is not available in sandbox
      expect(find.text('输入中文'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    });
  });
}
