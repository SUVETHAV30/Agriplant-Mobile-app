import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen> {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    setState(() => _isLoading = true);
    final farms = await Provider.of<DatabaseService>(context, listen: false).getFarms();
    setState(() {
      _farms = farms;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _farms.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('No farms added yet'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _addNewFarm,
                      child: const Text('Add Farm'),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: _farms.length,
                itemBuilder: (context, index) {
                  final farm = _farms[index];
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: const Icon(Icons.agriculture),
                      title: Text(farm['name']),
                      subtitle: Text(farm['location'] ?? 'No location set'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editFarm(farm),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteFarm(farm['id']),
                          ),
                        ],
                      ),
                      onTap: () => _viewFarmDetails(farm),
                    ),
                  );
                },
              );
  }

  Future<void> _addNewFarm() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const AddFarmDialog(),
    );

    if (result != null) {
      await Provider.of<DatabaseService>(context, listen: false).insertFarm(result);
      _loadFarms();
    }
  }

  Future<void> _editFarm(Map<String, dynamic> farm) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AddFarmDialog(initialFarm: farm),
    );

    if (result != null) {
      // Update farm in database
      _loadFarms();
    }
  }

  Future<void> _deleteFarm(int farmId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Farm'),
        content: const Text('Are you sure you want to delete this farm?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Delete farm from database
      _loadFarms();
    }
  }

  void _viewFarmDetails(Map<String, dynamic> farm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmDetailsScreen(farm: farm),
      ),
    );
  }
}

class AddFarmDialog extends StatefulWidget {
  final Map<String, dynamic>? initialFarm;

  const AddFarmDialog({super.key, this.initialFarm});

  @override
  State<AddFarmDialog> createState() => _AddFarmDialogState();
}

class _AddFarmDialogState extends State<AddFarmDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _soilTypeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialFarm != null) {
      _nameController.text = widget.initialFarm!['name'];
      _locationController.text = widget.initialFarm!['location'] ?? '';
      _areaController.text = widget.initialFarm!['area']?.toString() ?? '';
      _soilTypeController.text = widget.initialFarm!['soil_type'] ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _soilTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialFarm == null ? 'Add Farm' : 'Edit Farm'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Farm Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a farm name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(labelText: 'Area (acres)'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: _soilTypeController,
                decoration: const InputDecoration(labelText: 'Soil Type'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saveFarm,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveFarm() {
    if (_formKey.currentState!.validate()) {
      final farm = {
        'name': _nameController.text,
        'location': _locationController.text,
        'area': double.tryParse(_areaController.text),
        'soil_type': _soilTypeController.text,
      };
      Navigator.pop(context, farm);
    }
  }
}

class FarmDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> farm;

  const FarmDetailsScreen({super.key, required this.farm});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(farm['name']),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Location', farm['location'] ?? 'Not specified'),
            _buildInfoCard('Area', '${farm['area'] ?? 0} acres'),
            _buildInfoCard('Soil Type', farm['soil_type'] ?? 'Not specified'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Show farm on map
              },
              child: const Text('View on Map'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: Text(value),
      ),
    );
  }
} 