import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:near/api.dart';
import 'package:near/app_state.dart';
import 'package:near/main.dart';

void main() {
  testWidgets('Signed-out users see login and can open registration',
      (tester) async {
    final state = AppState(Api())..starting = false;
    await tester.pumpWidget(
        ChangeNotifierProvider.value(value: state, child: const NearApp()));
    expect(find.text('NEAR'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Create our little space'), findsOneWidget);
  });
}
