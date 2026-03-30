import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fanyi_tong/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home renders and is reachable', (tester) async {
    app.main();
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    expect(find.byType(app.FanyiTongApp), findsOneWidget);
    expect(find.byType(app.MainLayout), findsOneWidget);
    expect(find.text('翻译'), findsWidgets);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('学习'), findsWidgets);
    expect(find.text('拍照'), findsWidgets);
    expect(find.text('翻译首页'), findsOneWidget);
    expect(find.text('输入区'), findsOneWidget);
    expect(find.text('结果区'), findsOneWidget);

    await binding.takeScreenshot('home');
  });
}
