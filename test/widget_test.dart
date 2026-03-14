import 'package:flutter_test/flutter_test.dart';
import 'package:runlabag/main.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RunLabApp(
      hasCompletedOnboarding: false,
    ));

    // Verify that we are on the welcome screen
    expect(find.text('REDEFINA\nSEUS LIMITES'), findsOneWidget);
  });
}
