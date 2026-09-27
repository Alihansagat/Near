import 'package:geolocator/geolocator.dart';

class LocationSharingException implements Exception {
  final String message;
  const LocationSharingException(this.message);
  @override
  String toString() => message;
}

class SharedPosition {
  final double latitude;
  final double longitude;
  const SharedPosition(this.latitude, this.longitude);
}

abstract class LocationSharing {
  Future<SharedPosition> currentPosition();
}

class DeviceLocationSharing implements LocationSharing {
  @override
  Future<SharedPosition> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationSharingException(
          'Turn on Location Services and try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationSharingException(
          'Location permission is needed to share your distance.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationSharingException(
          'Location permission is blocked. Enable it in Settings and try again.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return SharedPosition(position.latitude, position.longitude);
  }
}
