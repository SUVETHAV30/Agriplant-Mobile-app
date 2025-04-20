import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailService extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> sendEmail({
    required String recipient,
    required String subject,
    required String body,
    List<String>? attachments,
  }) async {
    setState(true, null);

    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: recipient,
        queryParameters: {
          'subject': subject,
          'body': body,
        },
      );

      final canLaunch = await canLaunchUrl(emailLaunchUri);
      if (!canLaunch) {
        setState(false, 'Could not launch email client');
        return false;
      }

      await launchUrl(emailLaunchUri);
      setState(false, null);
      return true;
    } catch (e) {
      setState(false, 'Failed to send email: $e');
      return false;
    }
  }

  void setState(bool loading, String? error) {
    _isLoading = loading;
    _error = error;
    notifyListeners();
  }
} 