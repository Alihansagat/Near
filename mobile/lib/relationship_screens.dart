import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'life_screens.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'api.dart';
import 'app_state.dart';
import 'mascot.dart';
import 'screens.dart';
import 'theme.dart';
import 'distance.dart';

const featureTitles = {
  'envelopes': 'Open When',
  'story': 'Our Story',
  'places': 'Our Map',
  'wishlist': 'Our Wishlist',
  'messages': 'Messages'
};
const envelopeTitles = [
  'Open when you miss me',
  "Open when you're having a bad day",
  'Open on our anniversary'
];

class RelationshipHub extends StatelessWidget {
  const RelationshipHub({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final couple = state.home!['couple'] as Map;
    final partner = couple['user_1']['id'] == state.me?['id']
        ? couple['user_2']
        : couple['user_1'];
    final mood = HeartMood.parse(partner?['mood']);
    const sections = [
      ('envelopes', Icons.mark_email_unread_outlined),
      ('story', Icons.auto_stories_outlined),
      ('places', Icons.location_on_outlined),
      ('wishlist', Icons.favorite_border),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CozyCard(
          color: const Color(0xFFFBF0FC),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.favorite_outline, color: coral),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Mood',
                      style: Theme.of(context).textTheme.titleLarge)),
              TextButton(
                  onPressed: () => showMoodPicker(context, state, couple),
                  child: Text(state.me?['mood_day'] == state.home?['day']
                      ? 'Update mood'
                      : 'Share your mood')),
            ]),
            gap(6),
            if (state.me?['mood_day'] != state.home?['day'])
              const Text('How are you feeling today?',
                  style: TextStyle(color: mutedInk)),
            if (mood != null)
              Text('${partnerName(state)} is feeling ${mood.label}',
                  style: const TextStyle(color: mutedInk)),
            if (mood != null && partner?['mood_day'] != state.home?['day'])
              const Text('Last shared mood',
                  style: TextStyle(color: mutedInk, fontSize: 11)),
            if (partner != null) ...[
              gap(12),
              Wrap(spacing: 8, children: [
                OutlinedButton(
                    onPressed: state.busy
                        ? null
                        : () async {
                            final ok = await state
                                .run(() => state.api.post('messages/hug/'));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          ok ? 'Hug sent 🫂' : state.error!)));
                            }
                          },
                    child: const Text('Send hug 🫂')),
                OutlinedButton(
                    onPressed: () => openPage(
                        context, const RelationshipScreen(kind: 'messages')),
                    child: const Text('Send message')),
              ]),
            ],
          ])),
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Our little world',
              style: Theme.of(context).textTheme.headlineSmall)),
      CozyCard(
          child: Column(children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(sections[index].$2, color: coral),
              title: Text(featureTitles[sections[index].$1]!),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openPage(
                  context, RelationshipScreen(kind: sections[index].$1))),
        ],
        const Divider(height: 1),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined, color: coral),
            title: const Text('Important dates'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openPage(context, const ImportantDatesScreen())),
        const Divider(height: 1),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.auto_awesome_outlined, color: coral),
            title: const Text('Near Recap'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openPage(context, const RecapScreen())),
      ])),
    ]);
  }
}

class RelationshipScreen extends StatefulWidget {
  final String kind;
  const RelationshipScreen({super.key, required this.kind});
  @override
  State<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends State<RelationshipScreen> {
  List<dynamic> rows = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final api = context.read<AppState>().api;
      final all = <dynamic>[];
      String? path = '${widget.kind}/';
      while (path != null) {
        final page = await api.get(path);
        all.addAll(page['results'] as List);
        path = page['next'] == null
            ? null
            : '${widget.kind}/?${Uri.parse(page['next']).query}';
      }
      if (mounted) {
        setState(() {
          rows = all;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          loading = false;
        });
      }
    }
  }

  Future<void> edit() async {
    final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => FeatureEditor(kind: widget.kind)));
    if (saved == true) await load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return RefreshIndicator(
        onRefresh: () async {
          await state.run(state.reload);
          await load();
        },
        child: ListView(padding: const EdgeInsets.all(24), children: [
          NearEyebrow(switch (widget.kind) {
            'envelopes' => 'Letters for the moments that matter',
            'story' => 'The chapters of us',
            'places' => 'Across the distance',
            'wishlist' => 'Dreaming together',
            _ => 'Little notes from us',
          }),
          gap(7),
          Text(featureTitles[widget.kind]!,
              style: Theme.of(context).textTheme.headlineLarge),
          gap(22),
          if (widget.kind == 'places') OurMap(places: rows),
          FilledButton.icon(
              onPressed: edit,
              icon: const Icon(Icons.add),
              label: Text(switch (widget.kind) {
                'envelopes' => 'Create envelope',
                'story' => 'Add memory',
                'places' => 'Add memorable place',
                'messages' => 'Send message',
                _ => 'Add a wish'
              })),
          gap(),
          if (loading) const Center(child: CircularProgressIndicator()),
          if (error != null)
            TextButton(onPressed: load, child: Text('$error\nRetry')),
          if (!loading && error == null && rows.isEmpty)
            Text(switch (widget.kind) {
              'envelopes' => 'Your envelopes will appear here.',
              'story' => 'Add the first chapter of Our Story.',
              'places' => 'Save the places that mean something to you.',
              'messages' => 'Your hugs and messages will appear here.',
              _ => 'What would you love to do together?'
            }),
          for (final row in rows) ...[
            if (widget.kind == 'story')
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                          color: rose, shape: BoxShape.circle),
                      child:
                          const Icon(Icons.favorite, color: coral, size: 11)),
                  Container(width: 1, height: 155, color: hairline),
                ]),
                const SizedBox(width: 12),
                Expanded(
                    child: CozyCard(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                      NearEyebrow(DateFormat('MMMM d, yyyy')
                          .format(DateTime.parse(row['date']))),
                      gap(9),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(row['text'],
                                    style: const TextStyle(
                                        fontFamily: 'Newsreader',
                                        fontSize: 22,
                                        color: slate))),
                            if ((row['emoji'] ?? '').toString().isNotEmpty)
                              Text(row['emoji'].toString(),
                                  style: const TextStyle(fontSize: 20)),
                          ]),
                      if ((row['location'] ?? '').toString().isNotEmpty) ...[
                        gap(9),
                        Row(children: [
                          const Icon(Icons.location_on_outlined,
                              color: coral, size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                              child: Text(row['location'],
                                  style: const TextStyle(color: mutedInk))),
                        ]),
                      ],
                      if (row['photo_url'] != null) ...[
                        gap(12),
                        privateImage(state.api, row['photo_url']),
                      ],
                    ]))),
              ])
            else if (widget.kind == 'envelopes')
              CozyCard(
                  color: const Color(0xFFFBF0FC),
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: rose,
                              borderRadius: BorderRadius.circular(15)),
                          child: const Icon(Icons.mark_email_unread_outlined,
                              color: coral)),
                      title: Text(row['title'],
                          style: const TextStyle(
                              fontFamily: 'Newsreader',
                              fontSize: 21,
                              color: slate)),
                      subtitle: Text(row['creator'] == state.me?['id']
                          ? 'From you'
                          : 'From ${partnerName(state)}'),
                      trailing: const Icon(Icons.chevron_right, color: coral),
                      onTap: () =>
                          openPage(context, EnvelopeDetail(envelope: row))))
            else if (widget.kind == 'wishlist')
              CozyCard(
                  color: const Color(0xFFFBF0FC),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NearEyebrow('A wish for us'),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(row['title']),
                            value: row['completed'],
                            onChanged: state.busy
                                ? null
                                : (value) async {
                                    if (await state.run(() => state.api.patch(
                                        'wishlist/${row['id']}/',
                                        {'completed': value}))) {
                                      await load();
                                    }
                                  }),
                        if ((row['report'] ?? '').isNotEmpty)
                          Text(row['report'],
                              style: const TextStyle(color: mutedInk)),
                        if (row['report_photo_url'] != null)
                          privateImage(state.api, row['report_photo_url']),
                        TextButton.icon(
                            icon:
                                const Icon(Icons.add_photo_alternate_outlined),
                            label: const Text('Add completion report'),
                            onPressed: () async {
                              await openWishReport(context, row);
                              await load();
                            }),
                      ]))
            else if (widget.kind == 'messages')
              CozyCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(
                        row['sender'] == state.me?['id']
                            ? 'You'
                            : partnerName(state),
                        style: const TextStyle(color: coral)),
                    Text(row['text']),
                    Text(dateLabel(row['created_at']),
                        style: Theme.of(context).textTheme.bodySmall)
                  ]))
            else
              CozyCard(
                  child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.location_on_outlined, color: coral),
                      title: Text(row['title']),
                      subtitle:
                          Text('${row['latitude']}, ${row['longitude']}'))),
          ],
        ]));
  }
}

Widget privateImage(Api api, String url) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: Image.network(api.photoUrl(url),
        headers: api.photoHeaders(url),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, e, st) =>
            const Text('Photo unavailable. Pull to refresh.')));

class FeatureEditor extends StatefulWidget {
  final String kind;
  const FeatureEditor({super.key, required this.kind});
  @override
  State<FeatureEditor> createState() => _FeatureEditorState();
}

class _FeatureEditorState extends State<FeatureEditor> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      text = TextEditingController(),
      location = TextEditingController(),
      emoji = TextEditingController(text: '❤️'),
      latitude = TextEditingController(),
      longitude = TextEditingController();
  DateTime date = DateTime.now();
  List<PlatformFile> files = [];
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in [title, text, location, emoji, latitude, longitude]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
          allowMultiple: widget.kind == 'envelopes',
          withData: true,
          type: FileType.custom,
          allowedExtensions: widget.kind == 'story'
              ? ['jpg', 'jpeg', 'png', 'webp']
              : [
                  'jpg',
                  'jpeg',
                  'png',
                  'webp',
                  'mp4',
                  'mov',
                  'webm',
                  'mp3',
                  'm4a',
                  'wav',
                  'ogg',
                  'aac'
                ]);
      if (result != null && mounted) {
        setState(() {
          files = widget.kind == 'story'
              ? result.files
              : [...files, ...result.files];
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (widget.kind == 'envelopes' &&
        text.text.trim().isEmpty &&
        files.isEmpty) {
      setState(() => error = 'Add a text message or attachment.');
      return;
    }
    if (files.length > 12 ||
        files.any(
            (f) => f.size > (widget.kind == 'story' ? 10 : 50) * 1024 * 1024)) {
      setState(() =>
          error = 'Use up to 12 files, 50 MB each (10 MB for story photos).');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final data = <String, dynamic>{};
      switch (widget.kind) {
        case 'envelopes':
          data.addAll({'title': title.text.trim(), 'text': text.text.trim()});
        case 'story':
          data.addAll({
            'date': DateFormat('yyyy-MM-dd').format(date),
            'text': text.text.trim(),
            'location': location.text.trim(),
            'emoji': emoji.text.trim()
          });
        case 'places':
          data.addAll({
            'title': title.text.trim(),
            'latitude': double.parse(latitude.text),
            'longitude': double.parse(longitude.text)
          });
        case 'messages':
          data['text'] = text.text.trim();
        default:
          data['title'] = title.text.trim();
      }
      final body = FormData.fromMap(data);
      for (final file in files) {
        body.files.add(MapEntry(widget.kind == 'story' ? 'photo' : 'files',
            MultipartFile.fromBytes(file.bytes!, filename: file.name)));
      }
      await api.dio.post<dynamic>('${widget.kind}/', data: body);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = friendlyError(e);
          saving = false;
        });
      }
    }
  }

  Widget field(TextEditingController controller, String label,
          {bool required = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
              controller: controller,
              decoration: InputDecoration(labelText: label),
              maxLines: lines,
              validator: (s) => required && (s == null || s.trim().isEmpty)
                  ? 'Required'
                  : null));
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(featureTitles[widget.kind]!)),
      body: Form(
          key: form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            if (widget.kind == 'envelopes') ...[
              for (final trigger in envelopeTitles)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ActionChip(
                        label: Text(trigger),
                        onPressed: saving
                            ? null
                            : () => setState(() => title.text = trigger))),
              field(title, 'Custom trigger title', required: true),
            ] else if (['wishlist', 'places'].contains(widget.kind))
              field(title, 'Title', required: true),
            if (widget.kind == 'story') ...[
              ListTile(
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMMM d, yyyy').format(date)),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final chosen = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100));
                    if (chosen != null) setState(() => date = chosen);
                  }),
              field(emoji, 'Icon / emoji', required: true),
              field(location, 'Location'),
            ],
            if (['envelopes', 'story', 'messages'].contains(widget.kind))
              field(text,
                  widget.kind == 'story' ? 'Text description' : 'Text message',
                  required: widget.kind != 'envelopes', lines: 5),
            if (widget.kind == 'places') ...[
              coordinateField(latitude, 'Latitude', 90),
              coordinateField(longitude, 'Longitude', 180)
            ],
            if (['envelopes', 'story'].contains(widget.kind)) ...[
              OutlinedButton.icon(
                  onPressed: saving ? null : pick,
                  icon: const Icon(Icons.attach_file),
                  label: Text(widget.kind == 'story'
                      ? 'Photo'
                      : 'Photo attachments · Video attachments · Voice message audio files')),
              for (final file in files)
                ListTile(
                    title: Text(file.name),
                    trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: saving
                            ? null
                            : () => setState(() => files.remove(file)))),
            ],
            if (error != null)
              Text(error!, style: const TextStyle(color: coral)),
            gap(),
            FilledButton(
                onPressed: saving ? null : save,
                child: Text(saving ? 'Saving…' : 'Save')),
          ])));
}

Widget coordinateField(
        TextEditingController controller, String label, double bound) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            validator: (s) {
              final value = double.tryParse(s ?? '');
              return value == null || !value.isFinite || value.abs() > bound
                  ? 'Enter a value from -$bound to $bound'
                  : null;
            }));

class EnvelopeDetail extends StatelessWidget {
  final Map envelope;
  const EnvelopeDetail({super.key, required this.envelope});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        const Center(child: Text('💌', style: TextStyle(fontSize: 56))),
        gap(),
        Text(envelope['title'],
            style: Theme.of(context).textTheme.headlineSmall),
        gap(),
        Text(envelope['text']),
        gap(),
        for (final file in envelope['attachments'])
          Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: file['kind'] == 'photo'
                  ? privateImage(context.read<AppState>().api, file['url'])
                  : MediaAttachment(file: file)),
      ]);
}

class MediaAttachment extends StatefulWidget {
  final Map file;
  const MediaAttachment({super.key, required this.file});
  @override
  State<MediaAttachment> createState() => _MediaAttachmentState();
}

class _MediaAttachmentState extends State<MediaAttachment> {
  VideoPlayerController? video;
  AudioPlayer? audio;
  StreamSubscription<PlayerState>? subscription;
  bool ready = false, playing = false;
  String? error;
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    try {
      final api = context.read<AppState>().api;
      final url = api.photoUrl(widget.file['url']);
      if (widget.file['kind'] == 'video') {
        video = VideoPlayerController.networkUrl(Uri.parse(url),
            httpHeaders: api.photoHeaders(url));
        await video!.initialize();
        if (!mounted) return;
        video!.addListener(() {
          if (mounted) setState(() => playing = video!.value.isPlaying);
        });
      } else {
        audio = AudioPlayer();
        subscription = audio!.onPlayerStateChanged.listen((s) {
          if (mounted) setState(() => playing = s == PlayerState.playing);
        });
        // Download through the authenticated API; no credentials in media URLs.
        final result = await api.dio.get<List<int>>(url,
            options: Options(responseType: ResponseType.bytes));
        if (!mounted) return;
        await audio!.setSource(BytesSource(Uint8List.fromList(result.data!),
            mimeType: result.headers.value('content-type')));
      }
      if (mounted) setState(() => ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => error =
            'Could not load this attachment. Reopen the envelope to retry.');
      }
    }
  }

  @override
  void dispose() {
    subscription?.cancel();
    video?.dispose();
    audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CozyCard(
          child: Column(children: [
        Text(widget.file['name']),
        if (error != null)
          Text(error!)
        else if (!ready)
          const CircularProgressIndicator()
        else ...[
          if (video != null) ...[
            AspectRatio(
                aspectRatio: video!.value.aspectRatio,
                child: VideoPlayer(video!)),
            VideoProgressIndicator(video!, allowScrubbing: true)
          ],
          IconButton(
              tooltip: playing ? 'Pause' : 'Play',
              icon: Icon(playing ? Icons.pause : Icons.play_arrow),
              onPressed: () async {
                try {
                  if (video != null) {
                    if (playing) {
                      await video!.pause();
                    } else {
                      if (video!.value.position >= video!.value.duration) {
                        await video!.seekTo(Duration.zero);
                      }
                      await video!.play();
                    }
                  } else {
                    if (playing) {
                      await audio!.pause();
                    } else {
                      await audio!.resume();
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => error =
                        'Playback unavailable. Reopen the envelope to retry.');
                  }
                }
              }),
        ],
      ]));
}

class OurMap extends StatelessWidget {
  final List<dynamic> places;
  const OurMap({super.key, required this.places});
  Future<void> coordinates(BuildContext context) async {
    final state = context.read<AppState>();
    final lat =
        TextEditingController(text: state.me?['latitude']?.toString() ?? '');
    final lon =
        TextEditingController(text: state.me?['longitude']?.toString() ?? '');
    final key = GlobalKey<FormState>();
    String? error;
    bool saving = false;
    await showDialog<void>(
        context: context,
        builder: (dialog) => StatefulBuilder(
            builder: (dialog, update) => AlertDialog(
                    title: const Text('Your location'),
                    content: SingleChildScrollView(
                        child: Form(
                            key: key,
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                      'Share coordinates with your partner to calculate your distance.'),
                                  gap(),
                                  coordinateField(lat, 'Latitude', 90),
                                  coordinateField(lon, 'Longitude', 180),
                                  if (error != null) Text(error!)
                                ]))),
                    actions: [
                      TextButton(
                          onPressed:
                              saving ? null : () => Navigator.pop(dialog),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (!key.currentState!.validate()) return;
                                  update(() => saving = true);
                                  final ok = await state.run(() async {
                                    await state.api.patch('me/', {
                                      'latitude': double.parse(lat.text),
                                      'longitude': double.parse(lon.text)
                                    });
                                    await state.reload();
                                  });
                                  if (dialog.mounted) {
                                    if (ok) {
                                      Navigator.pop(dialog);
                                    } else {
                                      update(() {
                                        saving = false;
                                        error = state.error;
                                      });
                                    }
                                  }
                                },
                          child: const Text('Save'))
                    ])));
    // Controllers are released after the closing dialog animation.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    lat.dispose();
    lon.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final couple = state.home!['couple'];
    final me = state.me!;
    final partner = couple['user_1']['id'] == me['id']
        ? couple['user_2']
        : couple['user_1'];
    final positioned = me['latitude'] != null &&
        me['longitude'] != null &&
        partner?['latitude'] != null &&
        partner?['longitude'] != null;
    final distance = positioned
        ? distanceKm(me['latitude'], me['longitude'], partner['latitude'],
                partner['longitude'])
            .round()
        : couple['distance_km'];
    final points = <Map>[
      if (me['latitude'] != null) {...me, 'title': 'YOU 📍'},
      if (partner?['latitude'] != null) {...partner, 'title': 'PARTNER 📍'},
      ...places.cast<Map>(),
    ];
    return CozyCard(
        child: Column(children: [
      Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                  colors: [Color(0xFFF8EBF0), Color(0xFFF5F0FA)])),
          child: Column(children: [
            const NearEyebrow('Our distance'),
            gap(16),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.location_on_outlined, color: coral, size: 16),
              SizedBox(width: 5),
              Text('YOU',
                  style: TextStyle(
                      color: mutedInk, letterSpacing: 2, fontSize: 11)),
            ]),
            const Icon(Icons.arrow_downward, color: coral, size: 18),
            Text(
                distance == null
                    ? '— km'
                    : '${NumberFormat('#,##0', 'en_US').format(distance)} km',
                style: const TextStyle(
                    fontFamily: 'Newsreader', fontSize: 42, color: slate)),
            const Icon(Icons.arrow_upward, color: coral, size: 18),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.location_on_outlined, color: coral, size: 16),
              SizedBox(width: 5),
              Text('PARTNER',
                  style: TextStyle(
                      color: mutedInk, letterSpacing: 2, fontSize: 11)),
            ]),
            gap(12),
            Text(
                positioned
                    ? 'Calculated from your shared coordinates'
                    : 'Saved distance · Add both locations to calculate',
                textAlign: TextAlign.center,
                style: const TextStyle(color: mutedInk, fontSize: 12)),
          ])),
      gap(16),
      FilledButton.icon(
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
          icon: const Icon(Icons.my_location),
          label: Text(me['latitude'] == null
              ? 'Share my current location'
              : 'Update my current location')),
      TextButton(
          onPressed: state.busy ? null : () => coordinates(context),
          child: const Text('Enter coordinates manually')),
      if (me['latitude'] != null)
        TextButton(
            onPressed:
                state.busy ? null : () => state.run(state.stopSharingLocation),
            child: const Text('Stop sharing location')),
      ...[
        Align(
            alignment: Alignment.centerLeft,
            child: Text('Our places around the world',
                style: Theme.of(context).textTheme.titleLarge)),
        gap(8),
        Semantics(
            label: points
                .map(
                    (p) => '${p['title']}: ${p['latitude']}, ${p['longitude']}')
                .join('; '),
            child: SizedBox(height: 420, child: WorldMap(points: points))),
        for (var i = 0; i < points.length; i++)
          Text('${i + 1}. ${points[i]['title']}'),
      ],
    ]));
  }
}

class WorldMap extends StatefulWidget {
  final List<Map> points;
  const WorldMap({super.key, required this.points});
  @override
  State<WorldMap> createState() => _WorldMapState();
}

class _WorldMapState extends State<WorldMap> {
  final controller = MapController();
  late final Future<List<Polygon<Object>>> land = _loadLand();

  Future<List<Polygon<Object>>> _loadLand() async {
    final source = await rootBundle.loadString('assets/maps/land.json');
    final contours = jsonDecode(source) as List;
    return contours.map((outline) {
      final points = (outline as List).map((pair) {
        final coordinates = pair as List;
        return LatLng((coordinates[1] as num).toDouble(),
            (coordinates[0] as num).toDouble());
      }).toList();
      return Polygon<Object>(
          points: points,
          color: const Color(0xFFE6DCE7),
          borderColor: const Color(0xFFD0BFCE),
          borderStrokeWidth: .5);
    }).toList();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points
        .map((p) => LatLng((p['latitude'] as num).toDouble(),
            (p['longitude'] as num).toDouble()))
        .toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: FutureBuilder<List<Polygon<Object>>>(
        future: land,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const ColoredBox(
              color: Color(0xFFF8F2F6),
              child: Center(child: Text('Loading map…')),
            );
          }
          return Stack(children: [
            FlutterMap(
              mapController: controller,
              options: MapOptions(
                backgroundColor: const Color(0xFFF8F2F6),
                initialCenter:
                    points.isEmpty ? const LatLng(35, 30) : points.first,
                initialZoom: points.length > 1 ? 3 : 1.7,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(45),
                        maxZoom: 5)
                    : null,
                maxZoom: 6,
              ),
              children: [
                PolygonLayer<Object>(polygons: snapshot.data!),
                MarkerLayer(markers: [
                  for (var i = 0; i < points.length; i++)
                    Marker(
                      point: points[i],
                      width: 48,
                      height: 48,
                      child: Tooltip(
                        message:
                            widget.points[i]['title'] as String? ?? 'Place',
                        child: IconButton(
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            builder: (_) => SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                    widget.points[i]['title'] as String? ??
                                        'Place',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.location_on,
                              color: coral, size: 38),
                        ),
                      ),
                    ),
                ]),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(children: [
                FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () => controller.move(controller.camera.center,
                        (controller.camera.zoom + 1).clamp(1, 6)),
                    child: const Icon(Icons.add)),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () => controller.move(controller.camera.center,
                        (controller.camera.zoom - 1).clamp(1, 6)),
                    child: const Icon(Icons.remove)),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () => controller.rotate(0),
                    child: const Icon(Icons.explore_outlined)),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
