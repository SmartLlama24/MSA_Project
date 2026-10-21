import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paint_app/app/app.dart';

void main() {
  testWidgets('shows the four sections and switches between screens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MiniatureApp());

    expect(find.text('Good evening, painter'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Paints'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();
    expect(find.text('The Ashen Knight'), findsOneWidget);
    expect(find.text('IN PROGRESS'), findsNWidgets(2));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(find.text('PLANNED'), findsOneWidget);

    await tester.tap(find.text('Paints'));
    await tester.pumpAndSettle();
    expect(find.text('Mephiston Red'), findsOneWidget);

    await tester.tap(find.text('Wanted'));
    await tester.pumpAndSettle();
    expect(find.text('Aethermatic Blue'), findsOneWidget);
    expect(find.text('Mephiston Red'), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Miniature Painter'), findsOneWidget);
  });
}
