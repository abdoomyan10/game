import 'package:flutter_test/flutter_test.dart';
import 'package:game/app.dart';
import 'package:game/core/di/injection.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await configureDependencies();
  });

  testWidgets('App navigates from splash to home with game cards', (
    tester,
  ) async {
    await tester.pumpWidget(const App());

    expect(find.text('ألعاب'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('اختر لعبتك'), findsOneWidget);
    expect(find.text('Imposter '), findsOneWidget);
    expect(find.text('مافيا '), findsOneWidget);
  });
}
