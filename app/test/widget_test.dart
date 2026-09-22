import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';

void main() {
  testWidgets('장보기 항목을 추가한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(CloudService(false));
    await store.initialize();

    await tester.pumpWidget(HowMuchApp(store: store));
    expect(find.text('얼마였지'), findsOneWidget);
    expect(find.text('장보기 목록이 비었어요'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).first, '우유');
    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();

    expect(find.text('우유'), findsOneWidget);
    expect(find.text('1개'), findsOneWidget);
  });
}
