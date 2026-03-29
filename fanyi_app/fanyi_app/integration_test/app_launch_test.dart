import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:fanyi_tong/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches and shows shell UI', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 4));

    expect(find.text('翻译通'), findsWidgets);
    expect(find.text('即时翻译'), findsOneWidget);
  });
}
