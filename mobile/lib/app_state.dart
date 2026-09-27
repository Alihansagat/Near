import 'package:flutter/foundation.dart';
import 'api.dart';
import 'location_sharing.dart';

class AppState extends ChangeNotifier {
  final Api api;
  AppState(this.api) {
    api.onSessionExpired = () {
      me = null;
      home = null;
      notifyListeners();
    };
  }
  bool starting = true;
  bool busy = false;
  String? error;
  Map<String, dynamic>? me;
  Map<String, dynamic>? home;
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

  Future<void> reload() async {
    me = await api.get('me/');
    if (paired) {
      home = await api.get('home/');
      countdowns = [];
      String? countdownPath = 'meetings/';
      while (countdownPath != null) {
        final page = await api.get(countdownPath);
        countdowns.addAll(page['results'] as List);
        final next = page['next'] as String?;
        countdownPath =
            next == null ? null : 'meetings/?${Uri.parse(next).query}';
      }
      final datePage = await api.get('dates/');
      dates = datePage['results'] as List;
      nextDates = datePage['next'] as String?;
      final archive = await api.get('moments/');
      moments = archive['results'] as List;
      momentCount = archive['count'] as int;
      nextMoments = archive['next'] as int?;
    }
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
    try {
      await api.logout();
    } finally {
      me = null;
      home = null;
      dates = [];
      moments = [];
      countdowns = [];
      notifyListeners();
    }
  }
}
