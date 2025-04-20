import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<Map<String, dynamic>> _weatherData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWeatherData();
  }

  Future<void> _loadWeatherData() async {
    setState(() => _isLoading = true);
    try {
      final locationService = context.read<LocationService>();
      final position = await locationService.getCurrentLocation();
      if (position != null) {
        await _generateMockWeatherData(position.latitude, position.longitude);
      } else {
        print('Could not get current location');
      }
    } catch (e) {
      print('Error loading weather data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMockWeatherData(double latitude, double longitude) async {
    // Mock weather data generation
    final mockData = [
      {
        'date': DateTime.now(),
        'temperature': 25.0,
        'humidity': 65.0,
        'precipitation': 0.0,
        'windSpeed': 10.0,
      },
      {
        'date': DateTime.now().add(const Duration(days: 1)),
        'temperature': 23.0,
        'humidity': 70.0,
        'precipitation': 0.2,
        'windSpeed': 12.0,
      },
    ];
    setState(() => _weatherData = mockData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadWeatherData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildWeatherContent(),
    );
  }

  Widget _buildWeatherContent() {
    if (_weatherData.isEmpty) {
      return const Center(child: Text('No weather data available'));
    }

    return ListView.builder(
      itemCount: _weatherData.length,
      itemBuilder: (context, index) {
        final data = _weatherData[index];
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text('${data['date'].toString().split(' ')[0]}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Temperature: ${data['temperature']}°C'),
                Text('Humidity: ${data['humidity']}%'),
                Text('Precipitation: ${data['precipitation']}mm'),
                Text('Wind Speed: ${data['windSpeed']} km/h'),
              ],
            ),
          ),
        );
      },
    );
  }
} 