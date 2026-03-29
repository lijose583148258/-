import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/main.dart';

void main() {
  testWidgets('app widget smoke test', (tester) async {
    await tester.pumpWidget(const FanyiTongApp());
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('翻译通'), findsWidgets);
  });
}

