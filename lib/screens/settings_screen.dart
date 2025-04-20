import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../services/location_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildNotificationsSection(context),
          _buildLocationSection(context),
        ],
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Enable Notifications'),
                value: notificationService.notificationsEnabled,
                onChanged: (value) {
                  notificationService.updateSettings(
                    notificationsEnabled: value,
                  );
                },
              ),
              if (notificationService.notificationsEnabled) ...[
                SwitchListTile(
                  title: const Text('Weather Alerts'),
                  value: notificationService.weatherAlertsEnabled,
                  onChanged: (value) {
                    notificationService.updateSettings(
                      weatherAlertsEnabled: value,
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Task Reminders'),
                  value: notificationService.taskRemindersEnabled,
                  onChanged: (value) {
                    notificationService.updateSettings(
                      taskRemindersEnabled: value,
                    );
                  },
                ),
                SwitchListTile(
                  title: const Text('Email Notifications'),
                  value: notificationService.emailNotificationsEnabled,
                  onChanged: (value) {
                    notificationService.updateSettings(
                      emailNotificationsEnabled: value,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    return Consumer<LocationService>(
      builder: (context, locationService, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Current Location'),
                subtitle: locationService.currentPosition != null
                    ? Text(
                        '${locationService.currentPosition!.latitude.toStringAsFixed(6)}, '
                        '${locationService.currentPosition!.longitude.toStringAsFixed(6)}',
                      )
                    : const Text('Not available'),
                trailing: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => locationService.getCurrentLocation(),
                ),
              ),
              SwitchListTile(
                title: const Text('Background Location Updates'),
                value: locationService.backgroundUpdatesEnabled,
                onChanged: (value) {
                  locationService.setBackgroundUpdates(value);
                },
              ),
              if (locationService.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    locationService.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
} 