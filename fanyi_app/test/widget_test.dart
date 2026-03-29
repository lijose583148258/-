import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fanyi_tong/main.dart';

void main() {
  testWidgets('app widget smoke test', (tester) async {
    await tester.pumpWidget(const FanyiTongApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FanyiTongApp), findsOneWidget);
    expect(find.byType(MainLayout), findsOneWidget);
    expect(find.text('翻译'), findsOneWidget);
    expect(find.text('对话'), findsOneWidget);
    expect(find.text('学习'), findsOneWidget);
    expect(find.text('拍照'), findsOneWidget);
  });
}
