import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:runlabag/main.dart';
import 'package:runlabag/core/services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeService(),
        child: const RunLabApp(hasCompletedOnboarding: false),
      ),
    );

    await tester.pumpAndSettle();

    // Verify that we are on the welcome screen
    expect(find.text('REDEFINA\nSEUS LIMITES'), findsOneWidget);
  });
}
