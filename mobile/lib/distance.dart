import 'dart:math' as math;

double distanceKm(num lat1, num lon1, num lat2, num lon2) {
  double radians(num value) => value * math.pi / 180;
  final latitude = math.pow(math.sin(radians(lat2 - lat1) / 2), 2);
  final longitude = math.cos(radians(lat1)) *
      math.cos(radians(lat2)) *
      math.pow(math.sin(radians(lon2 - lon1) / 2), 2);
  return 6371 * 2 * math.asin(math.sqrt((latitude + longitude).clamp(0, 1)));
}

int? sharedDistanceKm(Map? me, Map? partner) {
  if (me?['latitude'] == null ||
      me?['longitude'] == null ||
      partner?['latitude'] == null ||
      partner?['longitude'] == null) {
    return null;
  }
  return distanceKm(
    me!['latitude'] as num,
    me['longitude'] as num,
    partner!['latitude'] as num,
    partner['longitude'] as num,
  ).round();
}
