import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'api.dart';
import 'app_state.dart';
import 'screens.dart';
import 'theme.dart';
import 'animations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ChangeNotifierProvider(
    create: (_) => AppState(Api())..init(),
    child: const NearApp(),
  ));
}

class NearApp extends StatelessWidget {
  const NearApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'NEAR',
        debugShowCheckedModeBanner: false,
        theme: nearTheme(),
        home: const AppGate(),
      );
}

class AppGate extends StatelessWidget {
  const AppGate({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (state.starting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Column(children: [
        if (state.error != null)
          SafeArea(
              bottom: false,
              child: MaterialBanner(
                content: Text(state.error!),
                actions: [
                  TextButton(
                      onPressed: () => state.run(() async {
                            if (state.api.access != null) await state.reload();
                          }),
                      child: const Text('Retry'))
                ],
              )),
        if (state.busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
            child: state.me == null
                ? const AuthScreen()
                : !state.paired
                    ? const PairScreen()
                    : const PartnerHugListener(child: MainShell())),
      ]),
    );
  }
}
