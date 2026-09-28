import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'theme.dart';

/// Poll only in the foreground. The per-user cursor survives reloads and sign-in.
class PartnerHugListener extends StatefulWidget {
  final Widget child;
  const PartnerHugListener({super.key, required this.child});
  @override
  State<PartnerHugListener> createState() => _PartnerHugListenerState();
}

class _PartnerHugListenerState extends State<PartnerHugListener>
    with WidgetsBindingObserver {
  Timer? timer;
  bool foreground = true;
  bool checking = false;
  bool showing = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 20), (_) => check());
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) check();
  }

  Future<void> check() async {
    if (!mounted || checking || !foreground || showing) return;
    checking = true;
    final state = context.read<AppState>();
    final userId = state.me?['id'];
    if (userId == null) {
      checking = false;
      return;
    }
    try {
      final key = 'last_hug_$userId';
      final seen =
          int.tryParse(await state.api.storage.read(key: key) ?? '') ?? 0;
      final data = await state.api.get('messages/latest-hug/');
      final id = data['id'] as int?;
      if (id != null && id > seen && mounted && state.me?['id'] == userId) {
        await state.api.storage.write(key: key, value: '$id');
        if (!mounted) return;
        showing = true;
        await showDialog<void>(
            context: context, builder: (context) => const HugDialog());
        showing = false;
      }
    } catch (_) {
      // An offline poll is retried on the next interval; it must not interrupt use.
    } finally {
      checking = false;
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class HugDialog extends StatefulWidget {
  const HugDialog({super.key});
  @override
  State<HugDialog> createState() => _HugDialogState();
}

class _HugDialogState extends State<HugDialog>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: beige,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
              animation: controller,
              builder: (_, child) {
                final t = MediaQuery.disableAnimationsOf(context)
                    ? 1.0
                    : Curves.easeOutBack.transform(controller.value);
                return Transform.scale(
                    scale: .5 + t * .5,
                    child: Opacity(
                        opacity: controller.value.clamp(0, 1), child: child));
              },
              child: const SizedBox(
                  height: 140,
                  width: 180,
                  child: Stack(alignment: Alignment.center, children: [
                    Icon(Icons.favorite, color: rose, size: 140),
                    Icon(Icons.favorite, color: coral, size: 92),
                    Positioned(
                        left: 5,
                        bottom: 10,
                        child: Icon(Icons.favorite, color: coral, size: 28)),
                    Positioned(
                        right: 4,
                        top: 8,
                        child: Icon(Icons.favorite, color: coral, size: 22)),
                  ]))),
          const SizedBox(height: 20),
          const Text('A hug from your partner', textAlign: TextAlign.center),
          const SizedBox(height: 8),
          const Text('A little closer, wherever you are.',
              textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep it close'))
        ],
      );
}

class GentleEntrance extends StatelessWidget {
  final Widget child;
  const GentleEntrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: child,
        builder: (_, value, child) => Opacity(
            opacity: value,
            child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)), child: child)),
      );
}
