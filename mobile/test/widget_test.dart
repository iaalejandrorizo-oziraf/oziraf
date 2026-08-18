import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oziraf/app_v2.dart';

void main() {
  testWidgets('renders OZIRAF branding', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: OzirafMark(size: 64)),
        ),
      ),
    );

    expect(find.byType(OzirafMark), findsOneWidget);
  });
}
