import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'app_state.dart';
import 'theme.dart';
import 'mascot.dart';
import 'relationship_screens.dart';
import 'distance.dart';
import 'life_screens.dart';

String dateLabel(dynamic value) => DateFormat('MMM d, yyyy · HH:mm')
    .format(DateTime.parse(value as String).toLocal());
Widget gap([double size = 16]) => SizedBox(height: size);

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool registering = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
        child: Center(
            child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                      child: Text('near·',
                          style: TextStyle(
                              fontFamily: 'Newsreader',
                              fontStyle: FontStyle.italic,
                              fontSize: 54,
                              fontWeight: FontWeight.w700,
                              color: coral))),
                  const Text('A little closer, every day.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: 'Newsreader',
                          fontStyle: FontStyle.italic,
                          fontSize: 20,
                          color: mutedInk)),
                  gap(36),
                  if (registering) ...[
                    TextFormField(
                        controller: name,
                        decoration:
                            const InputDecoration(labelText: 'Your name'),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'Enter your name' : null),
                    gap(),
                  ],
                  TextFormField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) =>
                          v!.contains('@') ? null : 'Enter an email'),
                  gap(),
                  TextFormField(
                      controller: password,
                      obscureText: true,
                      autofillHints: [
                        registering
                            ? AutofillHints.newPassword
                            : AutofillHints.password
                      ],
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => v!.isEmpty ? 'Enter a password' : null),
                  gap(24),
                  FilledButton(
                      onPressed: state.busy
                          ? null
                          : () {
                              if (!form.currentState!.validate()) return;
                              state.run(() async {
                                if (registering) {
                                  await state.api.register(
                                      name.text, email.text, password.text);
                                } else {
                                  await state.api
                                      .login(email.text, password.text);
                                }
                                await state.reload();
                              });
                            },
                      child: Text(registering
                          ? 'Create our little space'
                          : 'Welcome back')),
                  TextButton(
                      onPressed: state.busy
                          ? null
                          : () => setState(() => registering = !registering),
                      child: Text(registering
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account')),
                ],
              ))),
    )));
  }
}

class PairScreen extends StatefulWidget {
  const PairScreen({super.key});
  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final code = TextEditingController();
  @override
  void dispose() {
    code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SafeArea(
        child: ListView(padding: const EdgeInsets.all(28), children: [
      gap(40),
      const Icon(Icons.favorite_border, size: 60, color: coral),
      gap(),
      Text('A space for just two',
          style: Theme.of(context).textTheme.headlineLarge),
      gap(),
      const Text(
          'Start your shared space, or use the invitation your partner sent you.'),
      gap(28),
      FilledButton(
          onPressed: state.busy
              ? null
              : () => state.run(() async {
                    await state.api.post('couple/');
                    await state.reload();
                  }),
          child: const Text('Create our space')),
      gap(32),
      TextField(
          controller: code,
          decoration:
              const InputDecoration(labelText: 'Partner’s invite code')),
      gap(),
      OutlinedButton(
          onPressed: state.busy
              ? null
              : () => state.run(() async {
                    await state.api.post(
                        'couple/join/', {'invite_code': code.text.trim()});
                    await state.reload();
                  }),
          child: const Text('Join my partner')),
      TextButton(
          onPressed: state.busy ? null : () => state.run(state.signOut),
          child: const Text('Sign out')),
    ]));
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int tab = 0;
  final pages = PageController();
  Timer? refreshTimer;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && foreground) {
        final state = context.read<AppState>();
        state.refreshQuietly();
      }
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    pages.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    foreground = lifecycle == AppLifecycleState.resumed;
    if (foreground && mounted) {
      final state = context.read<AppState>();
      state.refreshQuietly();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
            child: PageView.builder(
          controller: pages,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (_, index) => _KeptTab(
              child: const [
            HomeScreen(),
            DailyPhotoScreen(),
            DatesScreen(),
            CountdownsScreen(),
            QuestionsScreen(),
          ][index]),
        )),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) {
            pages.jumpToPage(value);
            setState(() => tab = value);
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined), label: 'Daily'),
            NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined), label: 'Dates'),
            NavigationDestination(
                icon: Icon(Icons.hourglass_empty_rounded), label: 'Closer'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                label: 'Prompts'),
          ],
        ),
      );
}

class _KeptTab extends StatefulWidget {
  final Widget child;
  const _KeptTab({required this.child});
  @override
  State<_KeptTab> createState() => _KeptTabState();
}

class _KeptTabState extends State<_KeptTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Color? background;
  const PageBody({super.key, required this.children, this.background});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return ColoredBox(
      color: background ?? Colors.transparent,
      child: RefreshIndicator(
          onRefresh: () async {
            await state.run(state.reload);
          },
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: children,
                  )))),
    );
  }
}

void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
            appBar: AppBar(),
            body: SafeArea(
                child: Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 680),
                        child: page))))));

class SectionHeading extends StatelessWidget {
  final String eyebrow, title, subtitle;
  const SectionHeading(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(eyebrow.toUpperCase(),
            style: const TextStyle(
                color: coral,
                fontSize: 11,
                letterSpacing: 2.5,
                fontWeight: FontWeight.w700)),
        gap(10),
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        gap(8),
        Text(subtitle),
        gap(24),
      ]);
}

class NearTopBar extends StatelessWidget {
  const NearTopBar({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(children: [
          const Text('near',
              style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2.5,
                  color: coral)),
          const Text('·', style: TextStyle(fontSize: 28, color: coral)),
          const Spacer(),
          IconButton(
              tooltip: 'Memories',
              onPressed: () => openPage(context, const MomentsScreen()),
              icon: const Icon(Icons.auto_stories_outlined)),
          IconButton(
              tooltip: 'Our space',
              onPressed: () => openPage(context, const UsScreen()),
              icon: const Icon(Icons.settings_outlined)),
        ]),
      );
}

class NearEyebrow extends StatelessWidget {
  final String text;
  const NearEyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          color: coral,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700));
}

String partnerName(AppState state) {
  final couple = state.home?['couple'];
  if (couple == null) return 'Your person';
  final partner = couple['user_1']['id'] == state.me?['id']
      ? couple['user_2']
      : couple['user_1'];
  return partner?['full_name'] ?? 'Your person';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final home = state.home;
    if (home == null) {
      return const Center(child: Text('Pull to refresh your space.'));
    }
    final couple = home['couple'] as Map;
    final partner = couple['user_1']['id'] == state.me?['id']
        ? couple['user_2'] as Map?
        : couple['user_1'] as Map?;
    final liveDistance = sharedDistanceKm(state.me, partner);
    final savedDistance = couple['distance_km'];
    final distance = liveDistance ?? savedDistance;
    final meeting = home['meeting'] as Map?;
    final nextDate = home['next_date'] as Map?;
    return PageBody(children: [
      const NearTopBar(),
      const Text('A little closer, every day.',
          style: TextStyle(
              fontFamily: 'Newsreader',
              fontStyle: FontStyle.italic,
              fontSize: 23,
              color: mutedInk)),
      gap(18),
      CozyCard(
          child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
              color: rose, borderRadius: BorderRadius.circular(40)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.favorite, color: coral, size: 16),
              const SizedBox(width: 7),
              Text('${home['days_together']} days of us',
                  style: const TextStyle(
                      color: coral, fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
          ),
        ),
        gap(24),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: PersonBadge(
                  name: state.me?['full_name'] ?? 'You',
                  label: 'YOU',
                  character: mascotFor(state.me, couple),
                  mood: HeartMood.parse(state.me?['mood']),
                  onTap: () => showMoodPicker(context, state, couple))),
          const Padding(
              padding: EdgeInsets.only(top: 52),
              child: Icon(Icons.favorite, color: coral, size: 22)),
          Expanded(
              child: PersonBadge(
                  name: partnerName(state),
                  label: 'PARTNER',
                  character: mascotFor(partner, couple),
                  mood: HeartMood.parse(partner?['mood']))),
        ]),
        gap(12),
        const Divider(),
        Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on_outlined, color: coral, size: 19),
                const SizedBox(width: 5),
                Text(
                    distance == null
                        ? 'Connected at heart'
                        : '${NumberFormat.decimalPattern().format(distance)} km apart',
                    style: const TextStyle(color: mutedInk, fontSize: 14)),
              ]),
              if (partner != null)
                FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () async {
                          final ok = await state
                              .run(() => state.api.post('messages/hug/'));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(ok
                                    ? 'Hug sent 🫂'
                                    : state.error ?? 'Could not send hug.')));
                          }
                        },
                  icon: const Icon(Icons.favorite_outline, size: 17),
                  label: const Text('Send a hug'),
                ),
            ]),
        gap(4),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: state.busy
                  ? null
                  : () async {
                      final ok = await state.run(state.shareCurrentLocation);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok
                                ? 'Location shared with your partner'
                                : state.error ?? 'Could not share location.')));
                      }
                    },
              icon: const Icon(Icons.my_location, size: 16),
              label: Text(state.me?['latitude'] == null
                  ? 'Share my location'
                  : 'Update my location'),
            )),
        if (liveDistance != null)
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('Calculated from your shared locations',
                  style: TextStyle(color: mutedInk, fontSize: 11))),
      ])),
      Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: rose),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFFCFD), Color(0xFFF4E9F0)]),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NearEyebrow('The next hug'),
          gap(10),
          if (meeting != null) ...[
            SizedBox(
                width: double.infinity,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${home['days_until_meeting'] ?? '—'}',
                              style: const TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 76,
                                  height: 1,
                                  letterSpacing: -4,
                                  color: slate)),
                          const Padding(
                              padding: EdgeInsets.only(left: 9, bottom: 10),
                              child: Text('days',
                                  style: TextStyle(
                                      fontFamily: 'Newsreader',
                                      fontStyle: FontStyle.italic,
                                      fontSize: 24,
                                      color: coral))),
                        ]))),
            const Text('until we hold each other',
                style: TextStyle(fontSize: 16, color: mutedInk)),
            gap(18),
            const Divider(),
            Text(meeting['title'] ?? 'Our next meeting',
                style: Theme.of(context).textTheme.titleLarge),
            gap(4),
            Text(
                DateFormat('MMMM d, yyyy')
                    .format(DateTime.parse(meeting['target_date'])),
                style: const TextStyle(color: mutedInk)),
            CountdownActions(event: meeting),
          ] else ...[
            Text('Something to look forward to',
                style: Theme.of(context).textTheme.headlineSmall),
            gap(8),
            const Text('Make a little room for your next reunion.'),
            TextButton(
                onPressed: () => addCountdown(context),
                child: const Text('Add our next meeting →')),
          ],
        ]),
      ),
      Row(children: [
        Expanded(
            child: Text('A Little Moment for Today',
                style: Theme.of(context).textTheme.headlineSmall)),
        Text(DateFormat('MMM d').format(DateTime.parse(home['day'])),
            style: const TextStyle(color: mutedInk, fontSize: 13)),
      ]),
      gap(16),
      PhotoCard(
          data: home['recent_photo_day'] as Map? ?? home,
          today: home['recent_photo_day'] == null ||
              home['recent_photo_day']['day'] == home['day']),
      QuestionCard(key: ValueKey(home['day']), data: home, today: true),
      if (nextDate != null)
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NearEyebrow('Our next date'),
          gap(8),
          Text(activities[nextDate['type']] ?? 'Our date',
              style: Theme.of(context).textTheme.titleLarge),
          gap(4),
          Text(dateLabel(nextDate['scheduled_at'])),
          gap(8),
          Text(
              nextDate['status'] == 'accepted'
                  ? 'It’s a date ♥'
                  : 'Invitation waiting for a reply',
              style: const TextStyle(color: coral)),
        ])),
      const LifeCard(),
      const RelationshipHub(),
      FilledButton.icon(
          onPressed: state.busy ? null : () => planDate(context),
          icon: const Icon(Icons.add),
          label: const Text('Plan a date')),
      gap(24),
    ]);
  }
}

class PersonBadge extends StatelessWidget {
  final String name, label;
  final String character;
  final HeartMood? mood;
  final VoidCallback? onTap;
  const PersonBadge(
      {super.key,
      required this.name,
      required this.label,
      required this.character,
      this.mood,
      this.onTap});
  @override
  Widget build(BuildContext context) => Column(children: [
        Semantics(
          label: '$name, ${mood?.label ?? 'Mood not shared'}',
          button: onTap != null,
          child: Material(
            color: const Color(0xFFF9F1F4),
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                  dimension: 78,
                  child: Center(
                      child: HeartMascot(
                          character: character,
                          mood: mood ?? HeartMood.joyful,
                          size: 68))),
            ),
          ),
        ),
        gap(12),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        gap(3),
        Text(label,
            style: const TextStyle(
                color: mutedInk, fontSize: 10, letterSpacing: 1.5)),
        gap(10),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            decoration: BoxDecoration(
                color: beige,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: hairline)),
            child: Text(
                mood?.label ?? (onTap == null ? 'Not shared yet' : 'Set mood'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: coral, fontSize: 12)),
          ),
        ),
      ]);
}

Future<void> showMoodPicker(BuildContext context, AppState state, Map couple) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: beige,
      builder: (_) => _MoodPicker(
          state: state, initialCharacter: mascotFor(state.me, couple)),
    );

class _MoodPicker extends StatefulWidget {
  final AppState state;
  final String initialCharacter;
  const _MoodPicker({required this.state, required this.initialCharacter});
  @override
  State<_MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<_MoodPicker> {
  late String character = widget.initialCharacter;
  late HeartMood? mood = HeartMood.parse(widget.state.me?['mood']);
  bool saving = false;
  String? error;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !saving,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('How are you feeling today?',
                style: Theme.of(context).textTheme.headlineSmall),
            gap(8),
            const Text('A little signal to your person.'),
            gap(20),
            const Text('Your mascot'),
            gap(8),
            Row(children: [
              for (final value in ['male', 'female'])
                Expanded(
                    child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: OutlinedButton(
                    onPressed:
                        saving ? null : () => setState(() => character = value),
                    style: OutlinedButton.styleFrom(
                        backgroundColor: character == value ? rose : beige,
                        side: BorderSide(
                            color: character == value ? coral : rose)),
                    child: Column(children: [
                      HeartMascot(
                          character: value,
                          mood: mood ?? HeartMood.joyful,
                          size: 76),
                      Text(value == 'male' ? 'Male' : 'Female'),
                    ]),
                  ),
                )),
            ]),
            gap(20),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final value in [
                    HeartMood.joyful,
                    HeartMood.loving,
                    HeartMood.sleepy,
                    HeartMood.missing,
                    HeartMood.sad,
                    HeartMood.angry
                  ])
                    ChoiceChip(
                        label: Text(value.label),
                        selected: mood == value,
                        onSelected: saving
                            ? null
                            : (_) => setState(() => mood = value)),
                ]),
            gap(12),
            TextButton(
                onPressed: saving ? null : () => setState(() => mood = null),
                child: const Text('Keep mood private')),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: coral)),
              gap(12),
            ],
            SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() {
                            saving = true;
                            error = null;
                          });
                          final saved = await widget.state.run(() => widget
                              .state
                              .saveMascot(character, mood?.name ?? ''));
                          if (!context.mounted) return;
                          if (saved) {
                            setState(() => saving = false);
                            Navigator.pop(context);
                          } else {
                            setState(() {
                              saving = false;
                              error = widget.state.error ?? 'Please try again.';
                            });
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Save'),
                )),
          ]),
        ),
      );
}

class DailyPhotoScreen extends StatelessWidget {
  const DailyPhotoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final photos = state.home?['photos'] as List? ?? [];
    final shared = photos.length == 2;
    return PageBody(background: const Color(0xFFFFF7FD), children: [
      const NearTopBar(),
      Center(
          child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration:
            BoxDecoration(color: rose, borderRadius: BorderRadius.circular(30)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.favorite_border, color: coral, size: 14),
          SizedBox(width: 6),
          NearEyebrow('A daily ritual'),
        ]),
      )),
      gap(12),
      const Text('Two little moments.\nOne shared story.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Newsreader',
              fontStyle: FontStyle.italic,
              fontSize: 30,
              color: coral,
              height: 1.12)),
      gap(26),
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            color: lavender, borderRadius: BorderRadius.circular(20)),
        child: Row(children: [
          Icon(shared ? Icons.check_circle_outline : Icons.lock_outline,
              color: coral),
          const SizedBox(width: 12),
          Expanded(
              child: Text(
                  shared
                      ? 'Unlocked · Both shared'
                      : photos.isEmpty
                          ? 'Your pair is waiting for today’s photos'
                          : 'One photo shared · Waiting for the other',
                  style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      ),
      if (state.home != null) PhotoCard(data: state.home!, today: true),
      gap(12),
      if (MediaQuery.sizeOf(context).width < 360)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Memory Capsules',
              style: Theme.of(context).textTheme.headlineSmall),
          TextButton(
              onPressed: () => openPage(context, const MomentsScreen()),
              child: const Text('Open Archive →')),
        ])
      else
        Row(children: [
          Expanded(
              child: Text('Memory Capsules',
                  style: Theme.of(context).textTheme.headlineSmall)),
          TextButton(
              onPressed: () => openPage(context, const MomentsScreen()),
              child: const Text('Open Archive →')),
        ]),
      Text('${state.momentCount} shared days saved together',
          style: const TextStyle(color: mutedInk)),
      gap(12),
      CozyCard(
          color: const Color(0xFFFBF0FC),
          child: Row(children: [
            const Icon(Icons.auto_stories_outlined, color: coral),
            const SizedBox(width: 14),
            const Expanded(
                child: Text('Your moments, kept close in monthly capsules.')),
            IconButton(
                onPressed: () => openPage(context, const MomentsScreen()),
                icon: const Icon(Icons.arrow_forward_ios, size: 16)),
          ])),
    ]);
  }
}

class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final locked = state.home?['question_category_locked'] == true ||
        (state.home?['answers'] as List? ?? []).isNotEmpty;
    return PageBody(background: const Color(0xFFFFF7FD), children: [
      const NearTopBar(),
      const Center(child: NearEyebrow('A daily ritual')),
      gap(8),
      const Text('Daily Question',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Newsreader',
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: slate)),
      gap(4),
      const Text('Answer together. Uncover each other.',
          textAlign: TextAlign.center, style: TextStyle(color: mutedInk)),
      gap(24),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Deep', 'Fun', 'Future', 'Random'].map((label) {
              final selected = state.home?['question']?['category']
                      ?.toString()
                      .toLowerCase() ==
                  label.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    selectedColor: coral,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : slate,
                        fontWeight: FontWeight.w600),
                    onSelected: state.busy
                        ? null
                        : (value) async {
                            if (!value) return;
                            if (locked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'A partner has already answered. Choose a new category tomorrow.')));
                              return;
                            }
                            final ok = await state.run(() => state
                                .chooseQuestionCategory(label.toLowerCase()));
                            if (!ok && context.mounted && state.error != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(state.error!)));
                            }
                          }),
              );
            }).toList(),
          )),
      if (locked) ...[
        gap(8),
        const Text('Category locked for today once answered',
            style: TextStyle(fontSize: 12, color: mutedInk)),
      ],
      gap(20),
      if (state.home != null)
        QuestionCard(
            key: ValueKey(
                '${state.home!['day']}:${state.home!['question']?['category']}'),
            data: state.home!,
            today: true),
      gap(12),
      TextButton.icon(
        onPressed: () => openPage(context, const MomentsScreen()),
        icon: const Icon(Icons.auto_stories_outlined),
        label: const Text('Browse our answered questions'),
      ),
    ]);
  }
}

class PhotoCard extends StatelessWidget {
  final Map data;
  final bool today;
  const PhotoCard({super.key, required this.data, this.today = false});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final photos = data['photos'] as List? ?? [];
    final own = photos.where((p) => p['user'] == state.me?['id']).firstOrNull;
    final partner =
        photos.where((p) => p['user'] != state.me?['id']).firstOrNull;
    final both = data['photos_revealed'] == true;
    return CozyCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
              child:
                  NearEyebrow(today ? "Today's photo" : data['day'] as String)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: rose, borderRadius: BorderRadius.circular(20)),
            child: Text(both ? 'Shared pair' : 'Daily duo',
                style: const TextStyle(
                    fontSize: 11, color: coral, fontWeight: FontWeight.w600)),
          ),
        ]),
        gap(8),
        Text(data['photo_prompt'] as String? ?? 'A little moment from today',
            style: const TextStyle(
                fontFamily: 'Newsreader',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                color: slate)),
        gap(18),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: PhotoSlot(
                  photo: own,
                  label: 'You',
                  placeholder: today ? 'Share your moment' : 'No photo',
                  onTap: !today || own != null || state.busy
                      ? null
                      : () => state.run(() async {
                            final picked = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                maxWidth: 2048,
                                maxHeight: 2048,
                                imageQuality: 90);
                            if (picked == null) return;
                            await state.api.upload(picked);
                            await state.reload();
                          }))),
          const SizedBox(width: 12),
          Expanded(
              child: PhotoSlot(
                  photo: partner,
                  label: partnerName(state),
                  placeholder: partner == null
                      ? 'Waiting for their photo…'
                      : 'Share yours to reveal',
                  locked: partner != null && partner['photo_url'] == null)),
        ]),
        gap(14),
        Row(children: [
          Icon(both ? Icons.favorite : Icons.lock_outline,
              color: coral, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  both
                      ? 'Two moments, one shared story.'
                      : own != null
                          ? 'Your photo is saved. Waiting for ${partnerName(state)}.'
                          : 'Share yours to unlock today’s pair.',
                  style: const TextStyle(color: mutedInk, fontSize: 12))),
        ]),
      ],
    ));
  }
}

class PhotoSlot extends StatelessWidget {
  final dynamic photo;
  final String label;
  final String placeholder;
  final bool locked;
  final VoidCallback? onTap;
  const PhotoSlot(
      {super.key,
      this.photo,
      required this.label,
      required this.placeholder,
      this.locked = false,
      this.onTap});
  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api;
    final url = photo?['photo_url'] as String?;
    return Semantics(
      label: '$label: ${url == null ? placeholder : 'Photo shared'}',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: hairline),
              borderRadius: BorderRadius.circular(18)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: .76,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(17)),
                child: url == null
                    ? Container(
                        color: const Color(0xFFF8F2F5),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                                locked
                                    ? Icons.lock_outline
                                    : onTap != null
                                        ? Icons.add_a_photo_outlined
                                        : Icons.favorite_border,
                                color: coral,
                                size: 30),
                            gap(12),
                            Text(placeholder,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: mutedInk, fontSize: 12)),
                          ],
                        ),
                      )
                    : Image.network(api.photoUrl(url),
                        headers: api.photoHeaders(url),
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => const Center(
                            child: Text('Pull to refresh photo',
                                textAlign: TextAlign.center)),
                        loadingBuilder: (_, child, progress) => progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

class QuestionCard extends StatefulWidget {
  final Map data;
  final bool today;
  const QuestionCard({super.key, required this.data, this.today = false});
  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  bool revealed = false;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final data = widget.data;
    final question = data['question'];
    final answers = data['answers'] as List? ?? [];
    final own = answers.where((a) => a['user'] == state.me?['id']).firstOrNull;
    final partner =
        answers.where((a) => a['user'] != state.me?['id']).firstOrNull;
    final both = data['answers_revealed'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(22),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: hairline),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          NearEyebrow(widget.today
              ? "Today's prompt · ${question?['category'] ?? 'daily'}"
              : 'Our answers'),
          gap(16),
          Text(question?['question_text'] ?? 'A new question is on its way.',
              style: const TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 26,
                  height: 1.25,
                  color: slate)),
          gap(20),
          Row(children: [
            const Icon(Icons.favorite_border, color: coral, size: 17),
            const SizedBox(width: 7),
            Text('${answers.length} of 2 answered',
                style: const TextStyle(color: coral, fontSize: 12)),
          ]),
        ]),
      ),
      if (own != null || partner != null) ...[
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: NearEyebrow('Secret answers')),
        if (own != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: const Color(0xFFFBF0FC),
                borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('You · ${state.me?['full_name'] ?? 'Your answer'}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              gap(10),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15)),
                  child: Text(own['answer_text'] ?? 'Your answer is saved.',
                      style: const TextStyle(height: 1.45))),
            ]),
          ),
        if (partner != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: lavender, borderRadius: BorderRadius.circular(20)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(partnerName(state),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              gap(10),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15)),
                  child: revealed && both
                      ? Text(partner['answer_text'] ?? '',
                          style: const TextStyle(height: 1.45))
                      : const Column(children: [
                          Icon(Icons.lock_outline, color: coral),
                          SizedBox(height: 7),
                          Text('Tap Reveal to open both answers together.',
                              textAlign: TextAlign.center),
                        ])),
            ]),
          ),
      ],
      if (widget.today && question != null && own == null)
        FilledButton(
          onPressed: state.busy
              ? null
              : () async {
                  final value = await textDialog(context, 'Your answer',
                      'A little honesty brings us closer',
                      maxLength: 5000, multiline: true);
                  if (value == null || value.trim().isEmpty) return;
                  await state.run(() async {
                    await state.api.post('daily/answer/', {
                      'answer_text': value,
                      if (question['id'] != null) 'question_id': question['id'],
                      'question_category': question['category'],
                    });
                    await state.reload();
                  });
                },
          child: const Text('Answer today’s question'),
        ),
      if (both && !revealed)
        FilledButton.icon(
          onPressed: () => setState(() => revealed = true),
          icon: const Icon(Icons.auto_awesome_outlined),
          label: const Text('Reveal our answers'),
        ),
      if (own != null && !both)
        const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 12),
            child: Text('Your answer is saved. Waiting for your person ♥',
                style: TextStyle(color: mutedInk))),
      if (!both)
        const Padding(
            padding: EdgeInsets.only(bottom: 18),
            child: Row(children: [
              Icon(Icons.lock_outline, color: coral, size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Unlocks when you both answer',
                      style: TextStyle(color: mutedInk, fontSize: 12))),
            ])),
    ]);
  }
}

class MomentsScreen extends StatelessWidget {
  const MomentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final months = <String, List<dynamic>>{};
    for (final day in state.moments) {
      months
          .putIfAbsent((day['day'] as String).substring(0, 7), () => [])
          .add(day);
    }
    return PageBody(children: [
      SectionHeading(
          eyebrow: 'Our time capsules',
          title: 'Memories',
          subtitle: '${state.momentCount} shared days, kept close forever.'),
      if (months.isEmpty)
        const CozyCard(
            child:
                Text('Your first photo or answer starts your first capsule.')),
      for (final month in months.entries)
        Builder(builder: (context) {
          final previews = month.value
              .expand<dynamic>((day) => day['photos'] as List? ?? [])
              .where((photo) => photo['photo_url'] != null)
              .take(3)
              .toList();
          return CozyCard(
            color: const Color(0xFFFBF0FC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          DateFormat('MMMM yyyy')
                              .format(DateTime.parse('${month.key}-01')),
                          style: Theme.of(context).textTheme.headlineSmall)),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: lavender,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${month.value.length} days',
                        style: const TextStyle(color: mutedInk, fontSize: 11)),
                  ),
                ]),
                gap(14),
                Row(children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 7),
                    Expanded(
                        child: AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: i < previews.length
                            ? Image.network(
                                state.api.photoUrl(
                                    previews[i]['photo_url'] as String),
                                headers: state.api.photoHeaders(
                                    previews[i]['photo_url'] as String),
                                fit: BoxFit.cover,
                                errorBuilder: (_, error, stack) =>
                                    const ColoredBox(
                                        color: oat,
                                        child: Icon(Icons.image_outlined,
                                            color: coral)))
                            : const ColoredBox(
                                color: oat,
                                child:
                                    Icon(Icons.favorite_border, color: coral)),
                      ),
                    )),
                  ],
                ]),
                gap(12),
                Text(
                    month.key ==
                            (state.home?['day'] as String? ?? '').substring(
                                0,
                                (state.home?['day'] as String? ?? '').length >=
                                        7
                                    ? 7
                                    : 0)
                        ? 'Our story is still growing ♥'
                        : 'A chapter of us, saved for you.',
                    style: const TextStyle(color: mutedInk, fontSize: 12)),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () =>
                            openPage(context, AlbumScreen(month: month.key)),
                        child: const Text('Open capsule →'))),
              ],
            ),
          );
        }),
      if (state.nextMoments != null)
        TextButton(
            onPressed: state.busy ? null : () => state.run(state.moreMoments),
            child: const Text('Earlier capsules')),
    ]);
  }
}

class AlbumScreen extends StatefulWidget {
  final String month;
  const AlbumScreen({super.key, required this.month});
  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late Future<Map<String, dynamic>> album;
  @override
  void initState() {
    super.initState();
    album = fetch();
  }

  Future<Map<String, dynamic>> fetch() =>
      context.read<AppState>().api.get('moments/?month=${widget.month}');
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
      future: album,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: TextButton(
                  onPressed: () => setState(() => album = fetch()),
                  child: const Text('Could not open capsule. Try again')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final days = snapshot.data!['results'] as List;
        return RefreshIndicator(
            onRefresh: () async {
              final next = fetch();
              setState(() => album = next);
              await next;
            },
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SectionHeading(
                              eyebrow: 'From the first moment to the last',
                              title: DateFormat('MMMM yyyy')
                                  .format(DateTime.parse('${widget.month}-01')),
                              subtitle: '${days.length} pages of our story'),
                          for (final day in days) ...[
                            PhotoCard(data: day as Map),
                            if ((day['answers'] as List).isNotEmpty)
                              QuestionCard(key: ValueKey(day['day']), data: day)
                          ],
                          const Text('Every little moment brought us closer. ♥',
                              textAlign: TextAlign.center),
                          gap(24),
                        ]))));
      });
}

class DatesScreen extends StatelessWidget {
  const DatesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final upcoming = state.dates
        .where((date) =>
            date['status'] != 'declined' &&
            DateTime.parse(date['scheduled_at']).isAfter(DateTime.now()))
        .toList();
    final past = state.dates
        .where((date) =>
            date['status'] == 'declined' ||
            !DateTime.parse(date['scheduled_at']).isAfter(DateTime.now()))
        .toList();
    return PageBody(background: const Color(0xFFFFF7FD), children: [
      const NearTopBar(),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NearEyebrow('Shared ritual'),
          gap(5),
          Text('Virtual Dates',
              style: Theme.of(context).textTheme.headlineLarge),
          gap(4),
          const Text('Shared moments across the distance.',
              style: TextStyle(color: mutedInk, fontSize: 13)),
        ])),
        FilledButton.icon(
            onPressed: state.busy ? null : () => planDate(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Plan date')),
      ]),
      gap(24),
      if (upcoming.isEmpty)
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NearEyebrow('Our next date'),
          gap(9),
          Text('A moment to look forward to',
              style: Theme.of(context).textTheme.titleLarge),
          gap(8),
          const Text('Invite your person to share a little time together.'),
        ])),
      for (final date in upcoming) DateInvitationCard(date: date),
      gap(10),
      Text('Plan Your Next Togetherness',
          style: Theme.of(context).textTheme.titleLarge),
      gap(4),
      const Text('Little rituals for two screens',
          style: TextStyle(color: mutedInk, fontSize: 13)),
      gap(14),
      for (final entry in [
        (
          'movie',
          Icons.movie_outlined,
          'Movie night',
          'Pick a film to watch together.'
        ),
        (
          'dinner',
          Icons.restaurant_outlined,
          'Cook together',
          'Choose a recipe and share the moment.'
        ),
        (
          'gaming',
          Icons.sports_esports_outlined,
          'Play together',
          'Make time for a little fun.'
        ),
      ])
        CozyCard(
            child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: apricot, borderRadius: BorderRadius.circular(14)),
              child: Icon(entry.$2, color: coral)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(entry.$3,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(entry.$4,
                    style: const TextStyle(color: mutedInk, fontSize: 12)),
              ])),
          IconButton(
              onPressed: () => planDate(context, activity: entry.$1),
              icon: const Icon(Icons.arrow_forward_rounded, color: coral)),
        ])),
      if (past.isNotEmpty) ...[
        gap(8),
        Text('Past moments', style: Theme.of(context).textTheme.titleLarge),
        gap(10),
        for (final date in past)
          CozyCard(
              child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(activities[date['type']] ?? date['type'] as String),
            subtitle: Text(dateLabel(date['scheduled_at'])),
            trailing: Text(date['status'] as String,
                style: const TextStyle(color: mutedInk, fontSize: 12)),
          )),
      ],
      if (state.nextDates != null)
        TextButton(
            onPressed: state.busy ? null : () => state.run(state.moreDates),
            child: const Text('More dates')),
    ]);
  }
}

class DateInvitationCard extends StatelessWidget {
  final Map date;
  const DateInvitationCard({super.key, required this.date});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final incoming = date['creator'] != state.me?['id'];
    final pending = date['status'] == 'pending';
    return CozyCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
              color: apricot, borderRadius: BorderRadius.circular(20)),
          child: Text(
              pending
                  ? incoming
                      ? 'New invitation'
                      : 'Invitation sent'
                  : 'It’s a date',
              style: const TextStyle(
                  color: coral, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        gap(12),
        Text(activities[date['type']] ?? date['type'] as String,
            style: Theme.of(context).textTheme.titleLarge),
        gap(15),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: const Color(0xFFFBF0FC),
                borderRadius: BorderRadius.circular(15)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateLabel(date['scheduled_at']),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if ((date['detail'] ?? '').toString().isNotEmpty) ...[
                gap(5),
                Text(date['detail'].toString()),
              ],
            ])),
        if ((date['note'] ?? '').toString().isNotEmpty) ...[
          gap(12),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: oat, borderRadius: BorderRadius.circular(15)),
              child: Text('“${date['note']}”',
                  style: const TextStyle(
                      fontFamily: 'Newsreader',
                      fontStyle: FontStyle.italic,
                      fontSize: 18))),
        ],
        if (pending && incoming) ...[
          gap(16),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => state.run(() async {
                            await state.api.post('dates/${date['id']}/respond/',
                                {'status': 'accepted'});
                            await state.reload();
                          }),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Accept date'))),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed:
                        state.busy ? null : () => rescheduleDate(context, date),
                    child: const Text('Suggest another time'))),
            TextButton(
                onPressed: state.busy
                    ? null
                    : () => state.run(() async {
                          await state.api.post('dates/${date['id']}/respond/',
                              {'status': 'declined'});
                          await state.reload();
                        }),
                child: const Text('Decline')),
          ]),
        ] else ...[
          gap(12),
          Text(
              pending
                  ? 'Waiting for ${partnerName(state)} to reply'
                  : 'Time together is on the calendar ♥',
              style: const TextStyle(color: mutedInk, fontSize: 12)),
        ],
      ],
    ));
  }
}

const activities = {
  'movie': '🎬 Movie night',
  'dinner': '🍕 Dinner together',
  'gaming': '🎮 Gaming',
  'coffee': '☕ Coffee',
  'music': '🎵 Music',
  'quiz': '🧠 Quiz',
  'talk': '💬 Just talk',
  'surprise': '✨ Surprise'
};
Future<void> planDate(BuildContext context, {String? activity}) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlanDateSheet(initialActivity: activity));
}

class PlanDateSheet extends StatefulWidget {
  final String? initialActivity;
  const PlanDateSheet({super.key, this.initialActivity});
  @override
  State<PlanDateSheet> createState() => _PlanDateSheetState();
}

class _PlanDateSheetState extends State<PlanDateSheet> {
  late String activity = widget.initialActivity ?? 'movie';
  DateTime scheduled = DateTime.now().add(const Duration(days: 1));
  final note = TextEditingController();
  final detail = TextEditingController();
  String? error;
  @override
  void dispose() {
    note.dispose();
    detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('What do you want to do?',
                style: Theme.of(context).textTheme.headlineSmall),
            gap(20),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activities.entries
                    .map((e) => ChoiceChip(
                        label: Text(e.value),
                        selected: activity == e.key,
                        onSelected: (_) => setState(() => activity = e.key)))
                    .toList()),
            gap(),
            TextField(
                controller: detail,
                maxLength: 200,
                decoration: InputDecoration(
                    labelText: activity == 'movie'
                        ? 'Choose a movie'
                        : 'What’s the plan?',
                    hintText: activity == 'movie'
                        ? 'Interstellar'
                        : 'Something you both love')),
            gap(),
            OutlinedButton.icon(
                icon: const Icon(Icons.schedule),
                label: Text(dateLabel(scheduled.toIso8601String())),
                onPressed: () async {
                  final date = await showDatePicker(
                      context: context,
                      initialDate: scheduled,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)));
                  if (date == null || !context.mounted) return;
                  final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(scheduled));
                  if (time != null && mounted) {
                    setState(() => scheduled = DateTime(date.year, date.month,
                        date.day, time.hour, time.minute));
                  }
                }),
            const Text('Shown in your device’s local time.',
                style: TextStyle(fontSize: 12)),
            gap(),
            TextField(
                controller: note,
                maxLines: 3,
                maxLength: 2000,
                decoration:
                    const InputDecoration(labelText: 'A note for your person')),
            gap(),
            if (error != null) ...[
              Text(error!, style: const TextStyle(color: Colors.red)),
              gap()
            ],
            FilledButton(
                onPressed: state.busy
                    ? null
                    : () async {
                        if (!scheduled.isAfter(DateTime.now())) {
                          setState(() => error = 'Choose a future time.');
                          return;
                        }
                        final ok = await state.run(() async {
                          await state.api.post('dates/', {
                            'type': activity,
                            'scheduled_at': scheduled.toUtc().toIso8601String(),
                            'note': note.text.trim(),
                            'detail': detail.text.trim()
                          });
                          await state.reload();
                        });
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.pop(context);
                        } else {
                          setState(() => error = state.error);
                        }
                      },
                child: Text(state.busy ? 'Sending…' : 'Send invitation')),
          ],
        ));
  }
}

class UsScreen extends StatelessWidget {
  const UsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final couple = state.home?['couple'] as Map?;
    if (couple == null) return const SizedBox();
    return PageBody(children: [
      Text('Just us', style: Theme.of(context).textTheme.headlineLarge),
      gap(24),
      CozyCard(
          color: rose,
          child: Column(children: [
            const Icon(Icons.favorite, size: 48, color: coral),
            gap(),
            Text(
                '${couple['user_1']['full_name']} & ${couple['user_2']?['full_name'] ?? 'Your person'}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
          ])),
      if (couple['user_2'] == null)
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Invite your person',
              style: Theme.of(context).textTheme.titleLarge),
          gap(),
          SelectableText(couple['invite_code'] as String),
          gap(),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(
                      ClipboardData(text: couple['invite_code'] as String));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')));
                  }
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy code')),
            TextButton(
                onPressed: state.busy
                    ? null
                    : () => state.run(() async {
                          await state.api.post('couple/rotate-invite/');
                          await state.reload();
                        }),
                child: const Text('New code')),
          ]),
        ])),
      CozyCard(
          child: Column(children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Your name'),
            subtitle: Text(state.me!['full_name'] as String),
            trailing: const Icon(Icons.person_outline),
            onTap: state.busy
                ? null
                : () async {
                    final value = await textDialog(
                        context, 'Your name', 'How should your person see you?',
                        initial: state.me!['full_name'] as String,
                        maxLength: 120);
                    if (value == null || value.trim().isEmpty) return;
                    await state.run(() async {
                      await state.api.patch('me/', {'full_name': value.trim()});
                      await state.reload();
                    });
                  }),
        for (final entry in {
          'relationship_start_date': 'Together since',
          'distance_start_date': 'Distance started'
        }.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.value),
            subtitle: Text(couple[entry.key] ?? 'Not set'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: state.busy
                ? null
                : () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(couple[entry.key] ?? '') ??
                                DateTime.now(),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now());
                    if (date != null) {
                      await state.run(() async {
                        await state.api.patch('couple/',
                            {entry.key: DateFormat('yyyy-MM-dd').format(date)});
                        await state.reload();
                      });
                    }
                  },
          ),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Distance, km'),
            subtitle: Text('${couple['distance_km'] ?? 'Not set'}'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: state.busy
                ? null
                : () async {
                    final value = await textDialog(
                        context, 'Distance in kilometers', 'e.g. 4250',
                        initial: '${couple['distance_km'] ?? ''}');
                    if (value == null) return;
                    final distance = int.tryParse(value);
                    if (distance == null || distance < 0) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Enter a positive whole number.')));
                      }
                      return;
                    }
                    await state.run(() async {
                      await state.api
                          .patch('couple/', {'distance_km': distance});
                      await state.reload();
                    });
                  }),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Shared day time zone'),
            subtitle: Text(couple['time_zone'] as String),
            trailing: const Icon(Icons.public),
            onTap: state.busy
                ? null
                : () async {
                    final value = await textDialog(
                        context, 'Shared time zone', 'e.g. Asia/Almaty',
                        initial: couple['time_zone'] as String);
                    if (value != null) {
                      await state.run(() async {
                        await state.api
                            .patch('couple/', {'time_zone': value.trim()});
                        await state.reload();
                      });
                    }
                  }),
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Next meeting'),
            subtitle:
                Text(state.home?['meeting']?['title'] ?? 'Add a countdown'),
            trailing: const Icon(Icons.flight_takeoff),
            onTap: state.busy
                ? null
                : () => addCountdown(context,
                    event: state.home?['meeting'] as Map?)),
      ])),
      TextButton(
          onPressed: state.busy ? null : () => state.run(state.signOut),
          child: const Text('Sign out')),
      const Text('NEAR · A private space for two',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
    ]);
  }
}

Future<String?> textDialog(BuildContext context, String title, String hint,
        {String initial = '', int maxLength = 200, bool multiline = false}) =>
    showDialog<String>(
        context: context,
        builder: (_) => _TextDialog(
            title: title,
            hint: hint,
            initial: initial,
            maxLength: maxLength,
            multiline: multiline));

class _TextDialog extends StatefulWidget {
  final String title, hint, initial;
  final int maxLength;
  final bool multiline;
  const _TextDialog(
      {required this.title,
      required this.hint,
      required this.initial,
      required this.maxLength,
      required this.multiline});
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: widget.maxLength,
            minLines: widget.multiline ? 3 : 1,
            maxLines: widget.multiline ? 6 : 1,
            decoration: InputDecoration(hintText: widget.hint)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save'))
        ],
      );
}

const countdownKinds = {
  'meeting': '♥ Next meeting',
  'anniversary': '✦ Our anniversary',
  'birthday': '🎂 Birthday',
  'trip': '✈ Our trip',
  'other': '♡ Something special'
};
String countdownLabel(int days) => days == 0
    ? 'Today ♥'
    : days < 0
        ? '${-days} days ago'
        : '$days days';

class CountdownsScreen extends StatelessWidget {
  const CountdownsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final today = DateTime.parse(
        state.home?['day'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final meeting = state.home?['meeting'] as Map?;
    final others = state.countdowns
        .where((event) => event['id'] != meeting?['id'])
        .toList();
    return PageBody(background: const Color(0xFFFFF7FD), children: [
      const NearTopBar(),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Worth the wait.',
              style: TextStyle(
                  fontFamily: 'Newsreader',
                  fontStyle: FontStyle.italic,
                  fontSize: 30,
                  color: coral)),
          gap(5),
          const Text('Our next hug. Our milestones.',
              style: TextStyle(color: mutedInk, fontSize: 13)),
        ])),
        if (MediaQuery.sizeOf(context).width < 360)
          IconButton(
              tooltip: 'Add milestone',
              onPressed: state.busy ? null : () => addCountdown(context),
              icon: const Icon(Icons.add, color: coral))
        else
          OutlinedButton.icon(
              onPressed: state.busy ? null : () => addCountdown(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add milestone')),
      ]),
      gap(24),
      if (meeting != null)
        Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            border: Border.all(color: rose),
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7E8ED), Color(0xFFFFFDFD)]),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const NearEyebrow('Next meeting'),
            gap(20),
            SizedBox(
                width: double.infinity,
                child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${state.home?['days_until_meeting'] ?? '—'}',
                              style: const TextStyle(
                                  fontFamily: 'Newsreader',
                                  fontSize: 86,
                                  letterSpacing: -5,
                                  height: 1,
                                  color: coral)),
                          const Padding(
                              padding: EdgeInsets.only(left: 10, bottom: 10),
                              child:
                                  Text('days', style: TextStyle(fontSize: 20))),
                        ]))),
            const Text('until we hold each other',
                style: TextStyle(
                    fontFamily: 'Newsreader',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    color: slate)),
            gap(18),
            const Divider(),
            Text(meeting['title'] ?? 'Our next meeting',
                style: Theme.of(context).textTheme.titleLarge),
            gap(5),
            Text(
                DateFormat('EEEE, MMMM d, yyyy')
                    .format(DateTime.parse(meeting['target_date'])),
                style: const TextStyle(color: mutedInk)),
            if ((meeting['location'] ?? '').toString().isNotEmpty) ...[
              gap(5),
              Text(meeting['location'].toString(),
                  style: const TextStyle(color: mutedInk)),
            ],
            gap(14),
            CountdownActions(event: meeting),
          ]),
        )
      else
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const NearEyebrow('The next hug'),
          gap(10),
          Text('Make room for a reunion',
              style: Theme.of(context).textTheme.titleLarge),
          gap(8),
          const Text('Add a meeting to start counting down together.'),
          TextButton(
              onPressed: () => addCountdown(context),
              child: const Text('Add our next meeting →')),
        ])),
      Row(children: [
        Expanded(
            child: Text('Upcoming Milestones',
                style: Theme.of(context).textTheme.titleLarge)),
        Text('${others.length} saved',
            style: const TextStyle(color: mutedInk, fontSize: 12)),
      ]),
      gap(15),
      for (final event in others)
        CozyCard(
            child: Row(children: [
          Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: event['kind'] == 'birthday' ? apricot : lavender,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(
                  event['kind'] == 'birthday'
                      ? Icons.cake_outlined
                      : Icons.favorite_border,
                  color: coral)),
          const SizedBox(width: 13),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                NearEyebrow(countdownKinds[event['kind']] ?? 'Milestone'),
                gap(4),
                Text(event['title'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    DateFormat('MMM d, yyyy')
                        .format(DateTime.parse(event['target_date'])),
                    style: const TextStyle(color: mutedInk, fontSize: 12)),
              ])),
          Column(children: [
            Text(
                '${DateTime.parse(event['target_date']).difference(today).inDays}',
                style: const TextStyle(
                    fontSize: 27, fontWeight: FontWeight.w700, color: slate)),
            const Text('DAYS',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700, color: mutedInk)),
            PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 19),
                onSelected: (value) {
                  if (value == 'edit') {
                    addCountdown(context, event: event as Map);
                  }
                  if (value == 'delete') {
                    deleteCountdown(context, event as Map);
                  }
                },
                itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ]),
          ]),
        ])),
    ]);
  }
}

class CountdownActions extends StatelessWidget {
  final Map event;
  final bool light;
  const CountdownActions({super.key, required this.event, this.light = false});
  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppState>().busy;
    final style =
        light ? TextButton.styleFrom(foregroundColor: Colors.white) : null;
    return Wrap(spacing: 8, children: [
      TextButton.icon(
          style: style,
          onPressed: busy ? null : () => addCountdown(context, event: event),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit')),
      TextButton.icon(
          style: style,
          onPressed: busy ? null : () => deleteCountdown(context, event),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Delete')),
    ]);
  }
}

Future<bool> deleteCountdown(BuildContext context, Map event) async {
  final state = context.read<AppState>();
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
            title: const Text('Delete countdown?'),
            content:
                Text('Remove “${event['title']}” from your shared countdowns?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('Delete')),
            ],
          ));
  if (confirmed != true || !context.mounted) return false;
  final ok = await state.run(() async {
    await state.api.delete('meetings/${event['id']}/');
    await state.reload();
  });
  if (!ok && context.mounted && state.error != null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(state.error!)));
  }
  return ok;
}

Future<void> addCountdown(BuildContext context, {Map? event}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CountdownSheet(event: event));

class CountdownSheet extends StatefulWidget {
  final Map? event;
  const CountdownSheet({super.key, this.event});
  @override
  State<CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends State<CountdownSheet> {
  late final title = TextEditingController(text: widget.event?['title'] ?? '');
  late final location =
      TextEditingController(text: widget.event?['location'] ?? '');
  late String kind = widget.event?['kind'] ?? 'meeting';
  late DateTime day = widget.event == null
      ? DateTime.now().add(const Duration(days: 12))
      : DateTime.parse(widget.event!['target_date']);
  String? error;
  @override
  void dispose() {
    title.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  widget.event == null
                      ? 'Something to look forward to'
                      : 'Edit countdown',
                  style: Theme.of(context).textTheme.headlineSmall),
              gap(20),
              Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: countdownKinds.entries
                      .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: kind == e.key,
                          onSelected: state.busy
                              ? null
                              : (_) => setState(() => kind = e.key)))
                      .toList()),
              gap(20),
              TextField(
                  controller: title,
                  enabled: !state.busy,
                  maxLength: 160,
                  decoration: const InputDecoration(
                      labelText: 'Title', hintText: 'Our next chapter')),
              gap(),
              TextField(
                  controller: location,
                  enabled: !state.busy,
                  maxLength: 200,
                  decoration:
                      const InputDecoration(labelText: 'Place (optional)')),
              gap(),
              OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(DateFormat('MMMM d, yyyy').format(day)),
                  onPressed: state.busy
                      ? null
                      : () async {
                          final value = await showDatePicker(
                              context: context,
                              initialDate: day,
                              firstDate: day.isBefore(DateTime.now())
                                  ? day
                                  : DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 3650)));
                          if (value != null && mounted) {
                            setState(() => day = value);
                          }
                        }),
              gap(),
              if (error != null)
                Text(error!, style: const TextStyle(color: coral)),
              FilledButton(
                  onPressed: state.busy
                      ? null
                      : () async {
                          if (title.text.trim().isEmpty) {
                            setState(() => error = 'Give this moment a name.');
                            return;
                          }
                          final ok = await state.run(() async {
                            final payload = {
                              'title': title.text.trim(),
                              'location': location.text.trim(),
                              'kind': kind,
                              'target_date':
                                  DateFormat('yyyy-MM-dd').format(day)
                            };
                            if (widget.event == null) {
                              await state.api.post('meetings/', payload);
                            } else {
                              await state.api.patch(
                                  'meetings/${widget.event!['id']}/', payload);
                            }
                            await state.reload();
                          });
                          if (!context.mounted) return;
                          if (ok) {
                            Navigator.pop(context);
                          } else {
                            setState(() => error = state.error);
                          }
                        },
                  child: Text(widget.event == null
                      ? 'Save our countdown'
                      : 'Save changes')),
              if (widget.event != null)
                TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final deleted =
                                await deleteCountdown(context, widget.event!);
                            if (deleted && context.mounted) {
                              Navigator.pop(context);
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete countdown')),
            ]));
  }
}

Future<void> rescheduleDate(BuildContext context, dynamic invitation) async {
  final state = context.read<AppState>();
  final initial = DateTime.parse(invitation['scheduled_at']).toLocal();
  final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 1825)));
  if (day == null || !context.mounted) return;
  final time = await showTimePicker(
      context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return;
  final scheduled =
      DateTime(day.year, day.month, day.day, time.hour, time.minute);
  await state.run(() async {
    await state.api.post('dates/${invitation['id']}/reschedule/',
        {'scheduled_at': scheduled.toUtc().toIso8601String()});
    await state.reload();
  });
}
