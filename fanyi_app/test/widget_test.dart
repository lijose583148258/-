import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/main.dart';

void main() {
  testWidgets('app widget smoke test', (tester) async {
    await tester.pumpWidget(const FanyiTongApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FanyiTongApp), findsOneWidget);
    expect(find.byType(MainLayout), findsOneWidget);
    expect(find.text('翻译'), findsWidgets);
    expect(find.text('对话'), findsWidgets);
    expect(find.text('学习'), findsWidgets);
    expect(find.text('拍照'), findsWidgets);
  });
}
