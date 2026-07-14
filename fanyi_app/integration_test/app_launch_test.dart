import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fanyi_tong/main.dart' as app;
import 'package:fanyi_tong/screens/camera_screen.dart';
import 'package:fanyi_tong/screens/conversation_screen.dart';
import 'package:fanyi_tong/screens/learn_screen.dart';
import 'package:fanyi_tong/screens/translation_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home renders and is reachable', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(app.FanyiTongApp), findsOneWidget);
    expect(find.byType(app.MainLayout), findsOneWidget);
    expect(find.text('翻译'), findsWidgets);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('学习'), findsWidgets);
    expect(find.text('拍照'), findsWidgets);
    expect(find.text('输入'), findsOneWidget);
    expect(find.text('结果'), findsOneWidget);
    expect(find.byType(TranslationScreen), findsOneWidget);
    expect(find.byType(ConversationScreen), findsNothing);
    expect(find.byType(LearnScreen), findsNothing);
    expect(find.byType(CameraScreen), findsNothing);
  });
}
