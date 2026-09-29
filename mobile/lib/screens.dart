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
                  const Icon(Icons.favorite_rounded, size: 64, color: coral),
                  gap(24),
                  Text('NEAR',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge),
                  const Text('Closer, even from afar.',
                      textAlign: TextAlign.center),
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
            child: const [
          HomeScreen(),
          DailyPhotoScreen(),
          DatesScreen(),
          CountdownsScreen(),
          QuestionsScreen()
        ][tab]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (value) => setState(() => tab = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.camera_alt_outlined), label: 'Daily Photo'),
            NavigationDestination(
                icon: Icon(Icons.favorite_border), label: 'Dates'),
            NavigationDestination(
                icon: Icon(Icons.hourglass_empty_rounded), label: 'Countdown'),
            NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                label: 'Questions'),
          ],
        ),
      );
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return RefreshIndicator(
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
                ))));
  }
}

void openPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            Scaffold(appBar: AppBar(), body: SafeArea(child: page))));

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
    final upcoming = home['next_date'] ??
        state.dates
            .where((d) =>
                d['status'] != 'declined' &&
                DateTime.parse(d['scheduled_at']).isAfter(DateTime.now()))
            .firstOrNull;
    final liveDistance = sharedDistanceKm(state.me, partner);
    final hasSharedLocation = state.me?['latitude'] != null;
    final partnerHasSharedLocation = partner?['latitude'] != null;
    return PageBody(children: [
      Row(children: [
        const Text('near',
            style: TextStyle(
                fontSize: 34,
                letterSpacing: -1.8,
                fontWeight: FontWeight.w800,
                color: coral)),
        const Spacer(),
        IconButton(
            tooltip: 'Memories',
            onPressed: () => openPage(context, const MomentsScreen()),
            icon: const Icon(Icons.auto_awesome_outlined)),
        IconButton(
            tooltip: 'Our space',
            onPressed: () => openPage(context, const UsScreen()),
            icon: const Icon(Icons.tune_rounded))
      ]),
      gap(18),
      Text('A little closer, every day.',
          style: Theme.of(context).textTheme.headlineSmall),
      gap(20),
      CozyCard(
          child: Column(children: [
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: rose, borderRadius: BorderRadius.circular(30)),
            child: Text('♥  ${home['days_together']} days of us',
                style: const TextStyle(
                    color: coral, fontWeight: FontWeight.w600))),
        gap(16),
        Row(children: [
          Expanded(
              child: PersonBadge(
                  name: state.me?['full_name'] ?? 'You',
                  label: 'YOU',
                  character: mascotFor(state.me, couple),
                  mood: HeartMood.parse(state.me?['mood']),
                  onTap: () => showMoodPicker(context, state, couple))),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Icon(Icons.favorite, color: coral, size: 26)),
          Expanded(
              child: PersonBadge(
                  name: partnerName(state),
                  label: 'PARTNER',
                  character: mascotFor(partner, couple),
                  mood: HeartMood.parse(partner?['mood'])))
        ]),
        gap(24),
        Text(
            liveDistance != null
                ? '${NumberFormat.decimalPattern().format(liveDistance)} km apart'
                : couple['distance_km'] == null
                    ? 'Connected at heart'
                    : '${NumberFormat.decimalPattern().format(couple['distance_km'])} km apart',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        gap(6),
        if (liveDistance == null)
          Text(
              hasSharedLocation
                  ? partnerHasSharedLocation
                      ? 'Update location to calculate your distance'
                      : 'Waiting for ${partnerName(state)} to share location'
                  : 'Share location to calculate your distance',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: coral)),
        if (liveDistance != null)
          const Text('Calculated from your shared locations',
              style: TextStyle(fontSize: 12, color: coral)),
        TextButton.icon(
            onPressed: state.busy
                ? null
                : () async {
                    final ok = await state.run(state.shareCurrentLocation);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok
                            ? 'Location shared with your partner'
                            : state.error ?? 'Could not share location.')));
                  },
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: Text(hasSharedLocation
                ? 'Update my location'
                : 'Share my location')),
        gap(6),
        Text(
            state.life?['mode'] != null
                ? state.life!['mode'] == 'together'
                    ? "${state.life!['days']['together']} days side by side"
                    : "${state.life!['days']['apart']} days loving from afar"
                : home['days_apart'] == null
                    ? 'Set your distance story in Our space'
                    : "${home['days_apart']} days loving from afar",
            style: const TextStyle(fontSize: 12, color: coral)),
      ])),
      const LifeCard(),
      Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
              color: const Color(0xFFECE3E4),
              borderRadius: BorderRadius.circular(28)),
          child: Column(children: [
            const Text('THE NEXT HUG',
                style: TextStyle(color: slate, letterSpacing: 3, fontSize: 11)),
            gap(12),
            Text(home['days_until_meeting']?.toString().padLeft(2, '0') ?? '—',
                style: const TextStyle(
                    fontSize: 58,
                    height: 1.1,
                    fontWeight: FontWeight.w300,
                    color: slate)),
            Text(
                home['meeting'] == null
                    ? 'Something to look forward to'
                    : 'DAYS UNTIL WE MEET',
                style: const TextStyle(
                    color: slate, letterSpacing: 1.5, fontSize: 12)),
            gap(12),
            if (home['meeting'] != null)
              Text(
                  "${home['meeting']['title']} · ${DateFormat('MMM d').format(DateTime.parse(home['meeting']['target_date']))}",
                  style: const TextStyle(color: slate)),
            if (home['meeting'] != null)
              CountdownActions(event: home['meeting'] as Map),
            if (home['meeting'] == null)
              TextButton(
                  onPressed: () => addCountdown(context),
                  child: const Text('Add our next meeting →',
                      style: TextStyle(color: slate))),
          ])),
      const RelationshipHub(),
      PhotoCard(
          data: home['recent_photo_day'] as Map? ?? home,
          today: home['recent_photo_day'] == null ||
              home['recent_photo_day']['day'] == home['day']),
      QuestionCard(key: ValueKey(home['day']), data: home, today: true),
      if (upcoming != null)
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OUR NEXT DATE',
              style: TextStyle(color: coral, letterSpacing: 2, fontSize: 11)),
          gap(10),
          Text(activities[upcoming['type']] ?? 'Our date',
              style: Theme.of(context).textTheme.titleLarge),
          gap(6),
          Text(dateLabel(upcoming['scheduled_at'])),
          Text(
              upcoming['status'] == 'accepted'
                  ? 'It’s a date ♥'
                  : 'Invitation waiting for a reply',
              style: const TextStyle(color: coral, fontSize: 12))
        ])),
      FilledButton.icon(
          onPressed: state.busy ? null : () => planDate(context),
          icon: const Icon(Icons.add),
          label: const Text('Plan a date')),
      gap(22),
      const Text('Different places. Our little world.',
          textAlign: TextAlign.center,
          style: TextStyle(color: coral, fontStyle: FontStyle.italic)),
      gap(),
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
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: HeartMascot(
                        character: character, mood: mood ?? HeartMood.joyful))),
          ),
        ),
        gap(10),
        Text(label,
            style:
                const TextStyle(fontSize: 9, letterSpacing: 2, color: coral)),
        gap(4),
        Text(name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        if (onTap != null)
          TextButton(
              onPressed: onTap,
              child:
                  Text(mood?.label ?? 'Set mood', textAlign: TextAlign.center))
        else
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(mood?.label ?? 'Not shared yet',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: coral, fontSize: 12))),
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
    return PageBody(children: [
      const SectionHeading(
          eyebrow: 'A daily ritual',
          title: 'Your day. My day.',
          subtitle: 'Two little moments. One shared story.'),
      if (state.home != null) PhotoCard(data: state.home!, today: true),
      CozyCard(
          color: rose,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.auto_awesome_outlined, color: coral),
            gap(12),
            Text('365 days → 365 moments',
                style: Theme.of(context).textTheme.titleLarge),
            gap(8),
            const Text(
                'A fresh prompt every day. Your latest photos stay on Home for 24 hours and live on in your monthly memory capsules.'),
            gap(),
            OutlinedButton(
                onPressed: () => openPage(context, const MomentsScreen()),
                child: const Text('Open Memories →'))
          ])),
    ]);
  }
}

class QuestionsScreen extends StatelessWidget {
  const QuestionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return PageBody(children: [
      const SectionHeading(
          eyebrow: 'One question, two hearts',
          title: 'A little more of you.',
          subtitle: 'Make room for the conversations that matter.'),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Fun', 'Deep', 'Future', 'Random']
              .map((label) => ChoiceChip(
                  label: Text(label),
                  selected: state.home?['question']?['category']
                          ?.toString()
                          .toLowerCase() ==
                      label.toLowerCase(),
                  onSelected: state.busy
                      ? null
                      : (selected) async {
                          if (!selected) return;
                          if (state.home?['question_category_locked'] == true ||
                              (state.home?['answers'] as List? ?? [])
                                  .isNotEmpty) {
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
                        }))
              .toList()),
      gap(20),
      if (state.home != null)
        QuestionCard(
            key: ValueKey(
                '${state.home!['day']}:${state.home!['question']?['category']}'),
            data: state.home!,
            today: true),
      const Text(
          'One question each day, across Fun, Deep, Future and Random. Answer separately, then reveal together.',
          textAlign: TextAlign.center),
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
    final photos = data['photos'] as List;
    final own = photos.where((p) => p['user'] == state.me!['id']).firstOrNull;
    final partner =
        photos.where((p) => p['user'] != state.me!['id']).firstOrNull;
    return CozyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(today ? 'Today’s Photo' : data['day'] as String,
          style: Theme.of(context).textTheme.titleLarge),
      gap(6),
      Text(data['photo_prompt'] as String),
      gap(),
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
      gap(12),
      Text(
          data['photos_revealed'] == true
              ? 'Together today ♥ · ${data['day']}'
              : own != null
                  ? '♥ Your photo is waiting… ${partnerName(state)} hasn’t shared yet.'
                  : 'Share yours to unlock today’s pair.',
          style: const TextStyle(fontSize: 12, color: coral)),
    ]));
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
    return Column(children: [
      Semantics(
          label: '$label: $placeholder',
          button: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
                aspectRatio: .72,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: url == null
                        ? Container(
                            color: beige,
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
                                      color: coral),
                                  gap(10),
                                  Text(placeholder,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12))
                                ]))
                        : Image.network(api.photoUrl(url),
                            headers: api.photoHeaders(url),
                            fit: BoxFit.cover,
                            errorBuilder: (_, error, stack) => const Center(
                                child: Text('Pull to refresh photo',
                                    textAlign: TextAlign.center)),
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator())))),
          )),
      gap(8),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]);
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
  Map get data => widget.data;
  bool get today => widget.today;
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final question = data['question'];
    final answers = data['answers'] as List;
    final answered = answers.any((a) => a['user'] == state.me!['id']);
    return CozyCard(
        color: const Color(0xFFF1EEE7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (question != null) ...[
            Text((question['category'] as String).toUpperCase(),
                style: const TextStyle(
                    color: coral, fontSize: 10, letterSpacing: 2)),
            gap(8)
          ],
          Text(today ? 'Today’s Question' : 'Our answers',
              style: Theme.of(context).textTheme.titleLarge),
          gap(12),
          Text(question?['question_text'] ?? 'A new question is on its way.',
              style: const TextStyle(fontSize: 19, height: 1.4)),
          gap(),
          for (final answer in answers
              .where((a) => revealed && data['answers_revealed'] == true))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                  '${answer['user'] == state.me!['id'] ? 'You' : 'Your person'}: ${answer['answer_text']}'),
            ),
          if (today && question != null && !answered)
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
                            if (question['id'] != null)
                              'question_id': question['id'],
                            'question_category': question['category'],
                          });
                          await state.reload();
                        });
                      },
                child: const Text('Answer')),
          if (data['answers_revealed'] == true && !revealed) ...[
            const Text('♥ Both answered'),
            gap(12),
            FilledButton(
                onPressed: () => setState(() => revealed = true),
                child: const Text('Reveal our answers'))
          ],
          if (answered && data['answers_revealed'] != true)
            const Text('Your answer is saved. Waiting for your person ♥'),
          if (data['answers_revealed'] != true) ...[
            gap(8),
            const Row(children: [
              Icon(Icons.lock_outline, size: 16, color: coral),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Reveal · unlocks when you both answer',
                      style: TextStyle(fontSize: 12)))
            ])
          ],
        ]));
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
        CozyCard(
            color: rose,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.collections_bookmark_outlined,
                  color: coral, size: 36),
              gap(20),
              Text(
                  DateFormat('MMMM yyyy')
                      .format(DateTime.parse('${month.key}-01')),
                  style: Theme.of(context).textTheme.headlineSmall),
              gap(6),
              Text(month.key ==
                      (state.home?['day'] as String? ?? '').substring(
                          0,
                          (state.home?['day'] as String? ?? '').length >= 7
                              ? 7
                              : 0)
                  ? 'Our story is still growing ♥'
                  : 'A chapter of us, saved for you.'),
              gap(16),
              FilledButton(
                  onPressed: () =>
                      openPage(context, AlbumScreen(month: month.key)),
                  child: const Text('Open capsule →')),
            ])),
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
    return PageBody(children: [
      const SectionHeading(
          eyebrow: 'Close from anywhere',
          title: 'Virtual dates',
          subtitle: 'Turn “I miss you” into a plan.'),
      FilledButton.icon(
          onPressed: state.busy ? null : () => planDate(context),
          icon: const Icon(Icons.add),
          label: const Text('Plan a date')),
      gap(24),
      if (state.dates.isEmpty)
        const CozyCard(
            child:
                Text('No plans yet. Invite your person to something lovely.')),
      for (final date in state.dates)
        CozyCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(activities[date['type']] ?? date['type'] as String,
                    style: Theme.of(context).textTheme.titleLarge)),
            Chip(label: Text(date['status'] as String))
          ]),
          Text(dateLabel(date['scheduled_at'])),
          gap(8),
          if ((date['detail'] ?? '').isNotEmpty)
            Text(date['detail'],
                style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(date['note'] as String),
          if (date['status'] == 'pending' &&
              date['creator'] != state.me!['id'] &&
              DateTime.parse(date['scheduled_at'] as String)
                  .isAfter(DateTime.now())) ...[
            gap(),
            Wrap(spacing: 12, children: [
              for (final status in ['accepted', 'declined'])
                OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () => state.run(() async {
                              await state.api.post(
                                  'dates/${date['id']}/respond/',
                                  {'status': status});
                              await state.reload();
                            }),
                    child: Text(status == 'accepted' ? 'Accept' : 'Decline')),
              TextButton(
                  onPressed:
                      state.busy ? null : () => rescheduleDate(context, date),
                  child: const Text('Choose another time')),
            ]),
          ],
        ])),
      if (state.nextDates != null)
        TextButton(
            onPressed: state.busy ? null : () => state.run(state.moreDates),
            child: const Text('More dates')),
    ]);
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
Future<void> planDate(BuildContext context) async {
  await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PlanDateSheet());
}

class PlanDateSheet extends StatefulWidget {
  const PlanDateSheet({super.key});
  @override
  State<PlanDateSheet> createState() => _PlanDateSheetState();
}

class _PlanDateSheetState extends State<PlanDateSheet> {
  String activity = 'movie';
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
    return PageBody(children: [
      const SectionHeading(
          eyebrow: 'Good things are getting closer',
          title: 'Worth the wait.',
          subtitle: 'Our next hug. Our next adventure. Our milestones.'),
      FilledButton.icon(
          onPressed: state.busy ? null : () => addCountdown(context),
          icon: const Icon(Icons.add),
          label: const Text('Add a countdown')),
      gap(28),
      if (state.countdowns.isEmpty)
        const CozyCard(
            child:
                Text('Give your next happy moment a place on your timeline.')),
      for (final event in state.countdowns)
        IntrinsicHeight(
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
              width: 26,
              child: Column(children: [
                const Icon(Icons.favorite, size: 16, color: coral),
                Expanded(child: Container(width: 1, color: rose))
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: CozyCard(
                  color: event['kind'] == 'meeting' ? rose : Colors.white,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(countdownKinds[event['kind']] ?? 'A special day',
                            style: const TextStyle(fontSize: 11, color: coral)),
                        gap(8),
                        Text(event['title'],
                            style: Theme.of(context).textTheme.titleLarge),
                        gap(12),
                        Text(
                            countdownLabel(DateTime.parse(event['target_date'])
                                .difference(today)
                                .inDays),
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                color: coral)),
                        gap(8),
                        Text(DateFormat('MMMM d, yyyy')
                            .format(DateTime.parse(event['target_date']))),
                        if ((event['location'] ?? '').isNotEmpty)
                          Text(event['location']),
                        CountdownActions(event: event as Map),
                      ]))),
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
