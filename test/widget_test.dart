import 'package:flutter_test/flutter_test.dart';
import 'package:game/app.dart';

void main() {
  testWidgets('App shows shell with Arabic greeting', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();

    expect(find.text('مرحباً'), findsOneWidget);
  });
}
