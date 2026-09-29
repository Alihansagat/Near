import 'package:flutter/foundation.dart';
import 'api.dart';
import 'location_sharing.dart';

class AppState extends ChangeNotifier {
  final Api api;
  AppState(this.api) {
    api.onSessionExpired = () {
      _sessionVersion++;
      me = null;
      home = null;
      life = null;
      notifyListeners();
    };
  }
  bool starting = true;
  bool busy = false;
  String? error;
  Map<String, dynamic>? me;
  Map<String, dynamic>? home;
  Map<String, dynamic>? life;
  List<dynamic> dates = [];
  List<dynamic> countdowns = [];
  List<dynamic> moments = [];
  int momentCount = 0;
  int? nextMoments;
  String? nextDates;
  LocationSharing locationSharing = DeviceLocationSharing();
  bool get paired => me?['couple'] != null;

  Future<void> init() async {
    try {
      await api.restore();
      if (api.access != null) await reload();
    } catch (e) {
      error = friendlyError(e);
    }
    starting = false;
    notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = friendlyError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  int _sessionVersion = 0;
  Future<void>? _reloading;
  Future<void> reload() =>
      _reloading ??= _load().whenComplete(() => _reloading = null);

  bool _quietRefreshing = false;
  Future<void> refreshQuietly() async {
    if (busy || _reloading != null || _quietRefreshing || !paired) return;
    _quietRefreshing = true;
    try {
      final userId = me?['id'];
      final result = await Future.wait([api.get('home/'), api.get('life/')]);
      if (me?['id'] != userId || busy || _reloading != null) return;
      home = result[0];
      life = result[1];
      notifyListeners();
    } catch (_) {
      // Keep the current screen usable during an interrupted connection.
    } finally {
      _quietRefreshing = false;
    }
  }

  Future<void> _load() async {
    final session = _sessionVersion;
    final profile = await api.get('me/');
    if (session != _sessionVersion) return;
    if (profile['couple'] == null) {
      me = profile;
      home = null;
      life = null;
      notifyListeners();
      return;
    }
    Future<List<dynamic>> loadCountdowns() async {
      final rows = <dynamic>[];
      String? path = 'meetings/';
      while (path != null) {
        final page = await api.get(path);
        rows.addAll(page['results'] as List);
        path = page['next'] == null
            ? null
            : 'meetings/?${Uri.parse(page['next']).query}';
      }
      return rows;
    }

    final results = await Future.wait<Object>([
      api.get('home/'),
      api.get('life/'),
      loadCountdowns(),
      api.get('dates/'),
      api.get('moments/'),
    ]);
    if (session != _sessionVersion) return;
    me = profile;
    home = results[0] as Map<String, dynamic>;
    life = results[1] as Map<String, dynamic>;
    countdowns = results[2] as List<dynamic>;
    final datePage = results[3] as Map<String, dynamic>;
    dates = datePage['results'] as List;
    nextDates = datePage['next'] as String?;
    final archive = results[4] as Map<String, dynamic>;
    moments = archive['results'] as List;
    momentCount = archive['count'] as int;
    nextMoments = archive['next'] as int?;
    notifyListeners();
  }

  Future<void> chooseQuestionCategory(String category) async {
    await api.post('daily/question/category/', {'category': category});
    home = await api.get('home/');
  }

  Future<void> moreMoments() async {
    if (nextMoments == null) return;
    final result = await api.get('moments/?page=$nextMoments');
    moments.addAll(result['results'] as List);
    nextMoments = result['next'] as int?;
  }

  Future<void> saveMascot(String mascot, String mood) async {
    await api.patch('me/', {'mascot': mascot, 'mood': mood});
    me = {
      ...?me,
      'mascot': mascot,
      'mood': mood,
      'mood_day': mood.isEmpty ? null : home?['day']
    };
    final couple = home?['couple'];
    if (couple is Map) {
      for (final key in ['user_1', 'user_2']) {
        final person = couple[key];
        if (person is Map && person['id'] == me?['id']) {
          couple[key] = {...person, 'mascot': mascot, 'mood': mood};
        }
      }
    }
    notifyListeners();
  }

  Future<void> shareCurrentLocation() async {
    final point = await locationSharing.currentPosition();
    await api.patch('me/', {
      'latitude': point.latitude,
      'longitude': point.longitude,
    });
    await reload();
  }

  Future<void> stopSharingLocation() async {
    await api.patch('me/', {'latitude': null, 'longitude': null});
    await reload();
  }

  Future<void> moreDates() async {
    if (nextDates == null) return;
    // Keep pagination on the configured origin, including behind a proxy.
    final query = Uri.parse(nextDates!).query;
    final result = await api.get('dates/?$query');
    dates.addAll(result['results'] as List);
    nextDates = result['next'] as String?;
  }

  Future<void> signOut() async {
    _sessionVersion++;
    try {
      await api.logout();
    } finally {
      me = null;
      home = null;
      life = null;
      dates = [];
      moments = [];
      countdowns = [];
      notifyListeners();
    }
  }
}
