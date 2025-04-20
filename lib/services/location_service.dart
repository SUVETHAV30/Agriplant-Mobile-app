import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _backgroundUpdatesEnabled = false;
  String? _error;
  bool _isLoading = false;

  Position? get currentPosition => _currentPosition;
  bool get backgroundUpdatesEnabled => _backgroundUpdatesEnabled;
  String? get error => _error;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    await _checkLocationPermission();
    if (_backgroundUpdatesEnabled) {
      await _startBackgroundUpdates();
    }
  }

  Future<void> _checkLocationPermission() async {
    setState(true, null);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(false, 'Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(false, 'Location permissions are denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(false, 'Location permissions are permanently denied');
        return;
      }

      setState(false, null);
    } catch (e) {
      setState(false, 'Error checking location permission: $e');
    }
  }

  Future<Position?> getCurrentLocation() async {
    setState(true, null);
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(false, null);
      return _currentPosition;
    } catch (e) {
      setState(false, 'Error getting location: $e');
      return null;
    }
  }

  Future<void> setBackgroundUpdates(bool enabled) async {
    if (enabled == _backgroundUpdatesEnabled) return;

    _backgroundUpdatesEnabled = enabled;
    if (enabled) {
      await _startBackgroundUpdates();
    } else {
      await _stopBackgroundUpdates();
    }
    notifyListeners();
  }

  Future<void> _startBackgroundUpdates() async {
    try {
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100, // meters
        ),
      ).listen((Position position) {
        _currentPosition = position;
        notifyListeners();
      });
    } catch (e) {
      setState(false, 'Error starting background updates: $e');
    }
  }

  Future<void> _stopBackgroundUpdates() async {
    try {
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      setState(false, 'Error stopping background updates: $e');
    }
  }

  void setState(bool loading, String? error) {
    _isLoading = loading;
    _error = error;
    notifyListeners();
  }

  Future<double> calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  Future<List<Position>> getLocationHistory({
    required Duration duration,
  }) async {
    try {
      List<Position> positions = [];
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      await for (final position in stream) {
        positions.add(position);
        if (positions.length >= 100) break; // Limit to 100 positions
      }

      return positions;
    } catch (e) {
      _error = 'Error getting location history: $e';
      return [];
    }
  }

  Future<List<Position>> getFarmBoundary({
    required List<Map<String, double>> farmBoundary,
  }) async {
    try {
      List<Position> boundaryPositions = farmBoundary.map((point) {
        return Position.fromMap({
          'latitude': point['latitude']!,
          'longitude': point['longitude']!,
          'timestamp': DateTime.now(),
          'accuracy': 0.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speedAccuracy': 0.0,
        });
      }).toList();

      return boundaryPositions;
    } catch (e) {
      _error = 'Error getting farm boundary: $e';
      return [];
    }
  }

  Future<bool> isLocationWithinFarmBoundary(
    double latitude,
    double longitude,
    List<Map<String, double>> farmBoundary,
  ) async {
    try {
      // Convert farm boundary to Position objects
      List<Position> boundaryPositions = farmBoundary.map((point) {
        return Position.fromMap({
          'latitude': point['latitude']!,
          'longitude': point['longitude']!,
          'timestamp': DateTime.now(),
          'accuracy': 0.0,
          'altitude': 0.0,
          'heading': 0.0,
          'speed': 0.0,
          'speedAccuracy': 0.0,
        });
      }).toList();

      // Check if the point is within the boundary
      bool isInside = false;
      int j = boundaryPositions.length - 1;

      for (int i = 0; i < boundaryPositions.length; i++) {
        if ((boundaryPositions[i].latitude < latitude &&
                boundaryPositions[j].latitude >= latitude) ||
            (boundaryPositions[j].latitude < latitude &&
                boundaryPositions[i].latitude >= latitude)) {
          if (boundaryPositions[i].longitude +
                  (latitude - boundaryPositions[i].latitude) /
                      (boundaryPositions[j].latitude -
                          boundaryPositions[i].latitude) *
                      (boundaryPositions[j].longitude -
                          boundaryPositions[i].longitude) <
              longitude) {
            isInside = !isInside;
          }
        }
        j = i;
      }

      return isInside;
    } catch (e) {
      _error = 'Error checking location boundary: $e';
      return false;
    }
  }
} 