import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'app_state.dart';
import 'screens.dart';
import 'theme.dart';

class LifeCard extends StatelessWidget {
  const LifeCard({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final life = state.life;
    return CozyCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Our rhythm', style: Theme.of(context).textTheme.titleLarge),
      gap(12),
      SegmentedButton<String>(
          segments: const [
            ButtonSegment(
                value: 'apart', label: Text('Apart'), icon: Icon(Icons.public)),
            ButtonSegment(
                value: 'together',
                label: Text('Together'),
                icon: Icon(Icons.favorite_outline)),
          ],
          emptySelectionAllowed: true,
          selected: {if (life?['mode'] != null) life!['mode'] as String},
          onSelectionChanged: state.busy
              ? null
              : (values) async {
                  if (values.isEmpty) return;
                  await state.run(() async {
                    await state.api.post('life/', {'mode': values.first});
                    await state.reload();
                  });
                }),
      gap(12),
      Text(
          '${life?['days']?['together'] ?? 0} days together · ${life?['days']?['apart'] ?? 0} days apart'),
      Text(
          life?['since'] == null
              ? 'Choose your mode to start counting.'
              : 'Current chapter since ${life!['since']}',
          style: Theme.of(context).textTheme.bodySmall),
      TextButton(
          onPressed: () => showModalBottomSheet<void>(
              context: context,
              builder: (_) => SafeArea(
                      child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(24),
                          children: [
                        const Text('Our chapters'),
                        for (final row in (life?['history'] as List? ?? []))
                          ListTile(
                              title: Text(row['mode'] == 'together'
                                  ? 'Together'
                                  : 'Apart'),
                              subtitle: Text(
                                  '${row['start']} → ${row['end'] ?? 'Today'}')),
                      ]))),
          child: const Text('View history')),
      for (final event in (life?['notifications'] as List? ?? []))
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.notifications_active_outlined, color: coral),
            title: Text(event['title']),
            subtitle: Text(
                event['days'] == 0 ? 'Today' : 'In ${event['days']} days')),
    ]));
  }
}

class ImportantDatesScreen extends StatefulWidget {
  const ImportantDatesScreen({super.key});
  @override
  State<ImportantDatesScreen> createState() => _ImportantDatesScreenState();
}

class _ImportantDatesScreenState extends State<ImportantDatesScreen> {
  List<dynamic> rows = [];
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
      String? path = 'important-dates/';
      while (path != null) {
        final data = await api.get(path);
        all.addAll(data['results'] as List);
        path = data['next'] == null
            ? null
            : 'important-dates/?${Uri.parse(data['next']).query}';
      }
      if (mounted) {
        setState(() {
          rows = all;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
  }

  Future<void> edit([Map? row]) async {
    await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DateEditor(row: row));
    await load();
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        Text('Important dates',
            style: Theme.of(context).textTheme.headlineLarge),
        gap(),
        const Text(
            'Birthdays, anniversaries, and little reasons to celebrate. Monthly relationship milestones appear automatically.'),
        gap(),
        const Text('Reminders appear here while you use Near. Add them to your phone calendar for alerts when Near is closed.'),
        TextButton.icon(icon: const Icon(Icons.calendar_month_outlined), label: const Text('Add reminders to calendar'), onPressed: () async {
          final state = context.read<AppState>();
          final ok = await state.run(() async {
            final response = await state.api.dio.get<String>('important-dates/calendar/', options: Options(responseType: ResponseType.plain));
            await FilePicker.platform.saveFile(dialogTitle: 'Save Near reminders', fileName: 'near-dates.ics', bytes: Uint8List.fromList(utf8.encode(response.data!)));
          });
          if (ok && context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open near-dates.ics in your calendar and enable event alerts.')));
        }),
        gap(),
        FilledButton.icon(
            onPressed: edit,
            icon: const Icon(Icons.add),
            label: const Text('Add important date')),
        gap(),
        if (error != null)
          TextButton(onPressed: load, child: Text('$error · Retry')),
        for (final row in rows)
          CozyCard(
              child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row['title']),
                  subtitle: Text(
                      '${row['date']} · ${row['yearly'] ? 'Every year' : 'Once'}'),
                  onTap: () => edit(row),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                                    title: const Text('Delete this date?'),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'))
                                    ]));
                        if (yes != true || !context.mounted) return;
                        final state = context.read<AppState>();
                        if (await state.run(() async {
                          await state.api
                              .delete('important-dates/${row['id']}/');
                          await state.reload();
                        })) {
                          await load();
                        }
                      }))),
        const LifeCard(),
      ]);
}

class DateEditor extends StatefulWidget {
  final Map? row;
  const DateEditor({super.key, this.row});
  @override
  State<DateEditor> createState() => _DateEditorState();
}

class _DateEditorState extends State<DateEditor> {
  late final title = TextEditingController(text: widget.row?['title']);
  late DateTime day =
      DateTime.tryParse(widget.row?['date'] ?? '') ?? DateTime.now();
  late bool yearly = widget.row?['yearly'] ?? true;
  late int remind = widget.row?['remind_days'] ?? 1;
  String? error;
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SafeArea(
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(widget.row == null ? 'Add important date' : 'Edit important date',
            style: Theme.of(context).textTheme.titleLarge),
        gap(),
        TextField(
            controller: title,
            maxLength: 160,
            decoration: const InputDecoration(
                labelText: 'Birthday or special occasion')),
        TextButton.icon(
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(DateFormat.yMMMd().format(day)),
            onPressed: () async {
              final value = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200));
              if (value != null) setState(() => day = value);
            }),
        SwitchListTile(
            title: const Text('Repeat every year'),
            value: yearly,
            onChanged: (v) => setState(() => yearly = v)),
        DropdownButtonFormField<int>(
            initialValue: remind,
            decoration: const InputDecoration(labelText: 'Remind me'),
            items: [
              for (final n in {0, 1, 3, 7, remind})
                DropdownMenuItem(
                    value: n,
                    child: Text(n == 0 ? 'On the day' : '$n days before'))
            ],
            onChanged: (v) => setState(() => remind = v ?? 1)),
        gap(),
        if (error != null) Text(error!, style: const TextStyle(color: coral)),
        FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (title.text.trim().isEmpty) {
                      setState(() => error = 'Add a title.');
                      return;
                    }
                    setState(() {
                      saving = true;
                      error = null;
                    });
                    final state = context.read<AppState>();
                    final body = {
                      'title': title.text.trim(),
                      'date': DateFormat('yyyy-MM-dd').format(day),
                      'yearly': yearly,
                      'remind_days': remind
                    };
                    final ok = await state.run(() async {
                      if (widget.row == null) {
                        await state.api.post('important-dates/', body);
                      } else {
                        await state.api.patch(
                            'important-dates/${widget.row!['id']}/', body);
                      }
                      await state.reload();
                    });
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = state.error;
                      });
                    }
                  },
            child: const Text('Save')),
      ]))));
}

class RecapScreen extends StatefulWidget {
  const RecapScreen({super.key});
  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month - 1);
  Map<String, dynamic>? data;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final current = ++generation;
    setState(() {
      data = null;
      error = null;
    });
    try {
      final value = await context
          .read<AppState>()
          .api
          .get('recap/?month=${DateFormat('yyyy-MM').format(month)}');
      if (mounted && generation == current) setState(() => data = value);
    } catch (e) {
      if (mounted && generation == current) {
        setState(() => error = friendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(children: [
        Text('Near Recap', style: Theme.of(context).textTheme.headlineLarge),
        gap(),
        Row(children: [
          IconButton(
              onPressed: () {
                month = DateTime(month.year, month.month - 1);
                load();
              },
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: Text(DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center)),
          IconButton(
              onPressed: month.year == DateTime.now().year &&
                      month.month == DateTime.now().month
                  ? null
                  : () {
                      month = DateTime(month.year, month.month + 1);
                      load();
                    },
              icon: const Icon(Icons.chevron_right))
        ]),
        gap(),
        if (error != null)
          TextButton(onPressed: load, child: Text('$error · Retry')),
        if (data == null && error == null)
          const Center(child: CircularProgressIndicator()),
        if (data != null) ...[
          Text(data!['complete']
              ? 'A little time capsule of us.'
              : 'Your month so far'),
          gap(),
          for (final entry in {
            'Daily photos': data!['daily_photos'],
            'Days captured': data!['photo_days'],
            'Answers shared': data!['answers'],
            'Story memories': data!['memories'],
            'Dreams completed': data!['dreams'],
            'Days together': data!['days']['together'],
            'Days apart': data!['days']['apart']
          }.entries)
            CozyCard(
                child: Row(children: [
              Text('${entry.value}',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(width: 20),
              Expanded(child: Text(entry.key))
            ])),
        ],
      ]);
}

Future<void> openWishReport(BuildContext context, Map row) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => WishReport(row: row));

class WishReport extends StatefulWidget {
  final Map row;
  const WishReport({super.key, required this.row});
  @override
  State<WishReport> createState() => _WishReportState();
}

class _WishReportState extends State<WishReport> {
  late final text = TextEditingController(text: widget.row['report'] ?? '');
  XFile? photo;
  bool saving = false;
  String? error;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: SafeArea(
          child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('We did it!', style: Theme.of(context).textTheme.headlineSmall),
        gap(),
        Text(widget.row['title']),
        gap(),
        TextField(
            controller: text,
            maxLines: 4,
            maxLength: 5000,
            decoration: const InputDecoration(
                labelText: 'Tell the story of this dream')),
        TextButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(photo?.name ?? 'Attach a photo'),
            onPressed: saving
                ? null
                : () async {
                    try {
                      final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1800,
                          imageQuality: 85);
                      if (mounted && picked != null) {
                        setState(() => photo = picked);
                      }
                    } catch (e) {
                      if (mounted) setState(() => error = friendlyError(e));
                    }
                  }),
        if (error != null) Text(error!),
        FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (text.text.trim().isEmpty &&
                        photo == null &&
                        widget.row['report_photo_url'] == null) {
                      setState(() => error = 'Add a story or photo.');
                      return;
                    }
                    setState(() => saving = true);
                    final state = context.read<AppState>();
                    final ok = await state.run(() async {
                      final body = FormData.fromMap(
                          {'report': text.text.trim(), 'completed': true});
                      if (photo != null) {
                        body.files.add(MapEntry(
                            'report_photo',
                            MultipartFile.fromBytes(await photo!.readAsBytes(),
                                filename: photo!.name)));
                      }
                      await state.api.dio.patch<dynamic>(
                          'wishlist/${widget.row['id']}/',
                          data: body);
                    });
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        saving = false;
                        error = state.error;
                      });
                    }
                  },
            child: const Text('Save our memory')),
      ]))));
}
