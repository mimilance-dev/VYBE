import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vybe/app.dart';

void main() {
  testWidgets('landing page presents the hero and listening room preview',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VybeApp()));

    expect(find.text('Same song.\nSame moment.'), findsOneWidget);
    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Join a room'), findsOneWidget);
    expect(find.text('Afterglow'), findsOneWidget);
    expect(find.text('Both listening'), findsOneWidget);
  });

  testWidgets('landing page remains usable at a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: VybeApp()));

    expect(find.text('Create a room'), findsOneWidget);
    expect(find.text('Afterglow'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}