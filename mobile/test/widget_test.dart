import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oziraf/main.dart';

void main() {
  testWidgets('renders OZIRAF home experience', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(const OzirafApp());
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OzirafBottomNavigation), findsOneWidget);
  });
}
