import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rfplayer/app.dart';

void main() {
  testWidgets('App startup smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RFPlayerApp()));
    await tester.pump();

    expect(find.byType(RFPlayerApp), findsOneWidget);
  });
}
