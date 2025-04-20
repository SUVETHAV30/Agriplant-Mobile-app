import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/email_service.dart';

class EmailScreen extends StatefulWidget {
  const EmailScreen({super.key});

  @override
  State<EmailScreen> createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  List<String> _attachments = [];

  @override
  void dispose() {
    _recipientController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final emailService = Provider.of<EmailService>(context, listen: false);
    final success = await emailService.sendEmail(
      recipient: _recipientController.text,
      subject: _subjectController.text,
      body: _bodyController.text,
      attachments: _attachments,
    );

    if (success) {
      _clearForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sent successfully')),
        );
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailService.error ?? 'Failed to send email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _recipientController.clear();
    _subjectController.clear();
    _bodyController.clear();
    setState(() => _attachments = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearForm,
          ),
        ],
      ),
      body: Consumer<EmailService>(
        builder: (context, emailService, child) {
          if (emailService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextFormField(
                  controller: _recipientController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient',
                    hintText: 'Enter email address',
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter recipient email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject',
                    hintText: 'Enter email subject',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter subject';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Enter your message',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter message';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_attachments.isNotEmpty) ...[
                  const Text('Attachments:'),
                  const SizedBox(height: 8),
                  ..._attachments.map((path) => ListTile(
                    title: Text(path.split('/').last),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle),
                      onPressed: () => setState(() => _attachments.remove(path)),
                    ),
                  )),
                  const SizedBox(height: 16),
                ],
                ElevatedButton(
                  onPressed: _sendEmail,
                  child: const Text('Send Email'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 