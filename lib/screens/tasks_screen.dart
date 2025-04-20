import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';
  String _sortBy = 'Due Date';
  bool _sortAscending = true;
  final List<String> _categories = ['All', 'Planting', 'Harvesting', 'Maintenance', 'Irrigation', 'Fertilization'];
  final List<String> _statuses = ['All', 'Pending', 'In Progress', 'Completed', 'Overdue'];
  final List<String> _sortOptions = ['Due Date', 'Priority', 'Status', 'Category', 'Created Date'];
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _searchController = TextEditingController();
  final _filePicker = FilePicker.platform;
  
  String _selectedPriority = 'Medium';
  DateTime _selectedDate = DateTime.now();
  List<File> _attachments = [];
  List<int> _dependencies = [];

  Map<String, int> get _taskStatistics {
    final total = _tasks.length;
    final completed = _tasks.where((task) => task['status'] == 'Completed').length;
    final inProgress = _tasks.where((task) => task['status'] == 'In Progress').length;
    final overdue = _tasks.where((task) {
      final dueDate = DateTime.parse(task['due_date'] as String);
      return dueDate.isBefore(DateTime.now()) && task['status'] != 'Completed';
    }).length;
    final pending = _tasks.where((task) => task['status'] == 'Pending').length;

    return {
      'total': total,
      'completed': completed,
      'inProgress': inProgress,
      'overdue': overdue,
      'pending': pending,
    };
  }

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    try {
      await Provider.of<NotificationService>(context, listen: false).initialize();
    } catch (e) {
      print('Error initializing notifications: $e');
    }
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await Provider.of<DatabaseService>(context, listen: false).getTasks();
      setState(() => _tasks = tasks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading tasks: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredTasks {
    var filtered = _tasks.where((task) {
      final matchesCategory = _selectedCategory == 'All' || task['category'] == _selectedCategory;
      final matchesStatus = _selectedStatus == 'All' || task['status'] == _selectedStatus;
      final matchesSearch = _searchQuery.isEmpty || 
          (task['title'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          ((task['description'] as String?)?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      return matchesCategory && matchesStatus && matchesSearch;
    }).toList();

    // Sort tasks
    filtered.sort((a, b) {
      int compare;
      switch (_sortBy) {
        case 'Due Date':
          compare = DateTime.parse(a['due_date'] as String)
              .compareTo(DateTime.parse(b['due_date'] as String));
          break;
        case 'Priority':
          final priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
          compare = priorityOrder[a['priority']]!.compareTo(priorityOrder[b['priority']]!);
          break;
        case 'Status':
          final statusOrder = {'Overdue': 0, 'In Progress': 1, 'Pending': 2, 'Completed': 3};
          compare = statusOrder[a['status']]!.compareTo(statusOrder[b['status']]!);
          break;
        case 'Category':
          compare = (a['category'] as String).compareTo(b['category'] as String);
          break;
        case 'Created Date':
          compare = DateTime.parse(a['created_at'] as String)
              .compareTo(DateTime.parse(b['created_at'] as String));
          break;
        default:
          compare = 0;
      }
      return _sortAscending ? compare : -compare;
    });

    return filtered;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTaskDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => _showStatisticsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.data_usage),
            onPressed: _addSampleTasks,
            tooltip: 'Add Sample Tasks',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilters(),
          _buildSortOptions(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTasks.isEmpty
                    ? const Center(child: Text('No tasks available'))
                    : ListView.builder(
                        itemCount: _filteredTasks.length,
                        itemBuilder: (context, index) {
                          final task = _filteredTasks[index];
                          return _buildTaskCard(task);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search tasks...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptions() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _sortBy,
                items: _sortOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _sortBy = value!);
                },
                decoration: const InputDecoration(
                  labelText: 'Sort By',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () {
                setState(() => _sortAscending = !_sortAscending);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final dueDate = DateTime.parse(task['due_date'] as String);
    final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'Completed';
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => _showTaskDetails(context, task),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      task['title'] as String,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task['status'] as String).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task['status'] as String,
                          style: TextStyle(
                            color: _getStatusColor(task['status'] as String),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task['priority'] as String).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          task['priority'] as String,
                          style: TextStyle(
                            color: _getPriorityColor(task['priority'] as String),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (task['description'] != null && (task['description'] as String).isNotEmpty)
                Text(
                  task['description'] as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(dueDate)}',
                    style: TextStyle(
                      color: isOverdue ? Colors.red : Colors.grey,
                      fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditTaskDialog(context, task),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteTask(task['id'] as int),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final dueDateController = TextEditingController();
    String priority = 'Medium';
    String category = 'Planting';
    String status = 'Pending';
    int? selectedFarmId;

    // Fetch farms for selection
    final farms = await Provider.of<DatabaseService>(context, listen: false).getFarms();
    if (farms.isEmpty) {
      // Create a default farm if none exists
      final defaultFarm = {
        'name': 'Default Farm',
        'location': 'Default Location',
        'area': 100.0,
        'created_at': DateTime.now().toIso8601String(),
      };
      selectedFarmId = await Provider.of<DatabaseService>(context, listen: false).insertFarm(defaultFarm);
    } else {
      selectedFarmId = farms.first['id'] as int;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (farms.isNotEmpty)
                DropdownButtonFormField<int>(
                  value: selectedFarmId,
                  items: farms.map((farm) {
                    return DropdownMenuItem<int>(
                      value: farm['id'] as int,
                      child: Text(farm['name'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    selectedFarmId = value;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Farm',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(
                  labelText: 'Due Date',
                  border: OutlineInputBorder(),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    dueDateController.text = date.toIso8601String().split('T')[0];
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: category,
                items: _categories.where((c) => c != 'All').map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (value) => category = value!,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: priority,
                items: ['Low', 'Medium', 'High'].map((p) {
                  return DropdownMenuItem(value: p, child: Text(p));
                }).toList(),
                onChanged: (value) => priority = value!,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty || dueDateController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }

              final task = {
                'farm_id': selectedFarmId,
                'title': titleController.text,
                'description': descriptionController.text,
                'due_date': dueDateController.text,
                'priority': priority,
                'category': category,
                'status': status,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              };

              try {
                await Provider.of<DatabaseService>(context, listen: false).insertTask(task);
                await _loadTasks();

                // Schedule notification
                await Provider.of<NotificationService>(context, listen: false).scheduleTaskReminder(
                  title: 'Task Due: ${task['title']}',
                  body: task['description'] as String? ?? 'No description',
                  scheduledTime: DateTime.parse(task['due_date'] as String),
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task added successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error adding task: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTaskDialog(BuildContext context, Map<String, dynamic> task) async {
    final titleController = TextEditingController(text: task['title'] as String);
    final descriptionController = TextEditingController(text: task['description'] as String? ?? '');
    final dueDateController = TextEditingController(text: task['due_date'] as String);
    String priority = task['priority'] as String;
    String category = task['category'] as String;
    String status = task['status'] as String;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Task'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
              TextField(
                controller: dueDateController,
                decoration: const InputDecoration(labelText: 'Due Date'),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.parse(task['due_date'] as String),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    dueDateController.text = date.toIso8601String().split('T')[0];
                  }
                },
              ),
              DropdownButtonFormField<String>(
                value: category,
                items: _categories.where((c) => c != 'All').map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (value) => category = value!,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              DropdownButtonFormField<String>(
                value: priority,
                items: ['Low', 'Medium', 'High'].map((p) {
                  return DropdownMenuItem(value: p, child: Text(p));
                }).toList(),
                onChanged: (value) => priority = value!,
                decoration: const InputDecoration(labelText: 'Priority'),
              ),
              DropdownButtonFormField<String>(
                value: status,
                items: _statuses.where((s) => s != 'All').map((s) {
                  return DropdownMenuItem(value: s, child: Text(s));
                }).toList(),
                onChanged: (value) => status = value!,
                decoration: const InputDecoration(labelText: 'Status'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (titleController.text.isEmpty || dueDateController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields')),
                );
                return;
              }

              final updatedTask = {
                'id': task['id'],
                'title': titleController.text,
                'description': descriptionController.text,
                'due_date': dueDateController.text,
                'priority': priority,
                'category': category,
                'status': status,
                'updated_at': DateTime.now().toIso8601String(),
              };

              try {
                await Provider.of<DatabaseService>(context, listen: false).updateTask(updatedTask);
                await _loadTasks();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Task updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating task: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(int id) async {
    try {
      await Provider.of<DatabaseService>(context, listen: false).deleteTask(id);
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: $e')),
        );
      }
    }
  }

  void _showTaskDetails(BuildContext context, Map<String, dynamic> task) {
    final dueDate = DateTime.parse(task['due_date'] as String);
    final isOverdue = dueDate.isBefore(DateTime.now()) && task['status'] != 'Completed';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task['title'] as String),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task['description'] != null && (task['description'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(task['description'] as String),
                ),
              _buildDetailRow('Category', task['category'] as String),
              _buildDetailRow('Priority', task['priority'] as String),
              _buildDetailRow('Status', task['status'] as String),
              _buildDetailRow(
                'Due Date',
                DateFormat('MMM dd, yyyy').format(dueDate),
                isOverdue: isOverdue,
              ),
              _buildDetailRow('Created', DateFormat('MMM dd, yyyy').format(DateTime.parse(task['created_at'] as String))),
              _buildDetailRow('Last Updated', DateFormat('MMM dd, yyyy').format(DateTime.parse(task['updated_at'] as String))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isOverdue = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: TextStyle(
              color: isOverdue ? Colors.red : null,
              fontWeight: isOverdue ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showStatisticsDialog(BuildContext context) {
    final stats = _taskStatistics;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Tasks', stats['total']!.toString()),
            _buildStatRow('Completed', stats['completed']!.toString()),
            _buildStatRow('In Progress', stats['inProgress']!.toString()),
            _buildStatRow('Overdue', stats['overdue']!.toString()),
            _buildStatRow('Pending', stats['pending']!.toString()),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: stats['total']! > 0 ? stats['completed']! / stats['total']! : 0,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            const SizedBox(height: 8),
            Text(
              'Completion Rate: ${(stats['total']! > 0 ? (stats['completed']! / stats['total']! * 100) : 0).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Future<void> _addAttachment() async {
    try {
      final result = await _filePicker.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachments.addAll(result.files.map((file) => File(file.path!)));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding attachment: $e')),
      );
    }
  }

  Future<void> _addDependency(Map<String, dynamic> currentTask) async {
    final tasks = await Provider.of<DatabaseService>(context, listen: false).getTasks();
    final availableTasks = tasks.where((task) => task['id'] != currentTask['id']).toList();

    if (availableTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other tasks available to add as dependency')),
      );
      return;
    }

    final selectedTask = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Task Dependency'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTasks.length,
            itemBuilder: (context, index) {
              final task = availableTasks[index];
              return ListTile(
                title: Text(task['title']),
                subtitle: Text('Due: ${task['due_date']}'),
                onTap: () => Navigator.pop(context, task),
              );
            },
          ),
        ),
      ),
    );

    if (selectedTask != null) {
      setState(() {
        _dependencies.add(selectedTask['id']);
      });
    }
  }

  Future<void> _saveTask(Map<String, dynamic>? existingTask) async {
    if (_formKey.currentState!.validate()) {
      try {
        final task = {
          'title': _titleController.text,
          'description': _descriptionController.text,
          'priority': _selectedPriority,
          'status': _selectedStatus,
          'category': _selectedCategory,
          'due_date': _selectedDate.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (existingTask != null) {
          task['id'] = existingTask['id'];
          await Provider.of<DatabaseService>(context, listen: false).updateTask(task);
        } else {
          final taskId = await Provider.of<DatabaseService>(context, listen: false).insertTask(task);
          
          // Save attachments
          for (final attachment in _attachments) {
            await Provider.of<DatabaseService>(context, listen: false).insertTaskAttachment({
              'task_id': taskId,
              'file_path': attachment.path,
              'file_name': attachment.path.split('/').last,
              'file_type': attachment.path.split('.').last,
              'created_at': DateTime.now().toIso8601String(),
            });
          }

          // Save dependencies
          for (final dependencyId in _dependencies) {
            await Provider.of<DatabaseService>(context, listen: false).insertTaskDependency({
              'task_id': taskId,
              'dependent_task_id': dependencyId,
              'dependency_type': 'blocks',
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving task: $e')),
          );
        }
      }
    }
  }

  Future<void> _ensureFarmExists() async {
    final farms = await Provider.of<DatabaseService>(context, listen: false).getFarms();
    if (farms.isEmpty) {
      // Create a sample farm
      final sampleFarm = {
        'name': 'Main Farm',
        'location': 'Farm Location',
        'area': 100.0,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      try {
        await Provider.of<DatabaseService>(context, listen: false).insertFarm(sampleFarm);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sample farm created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating sample farm: $e')),
          );
        }
      }
    }
  }

  Future<void> _addSampleTasks() async {
    // First ensure we have a farm
    await _ensureFarmExists();
    
    // Get the farms again to ensure we have the latest data
    final farms = await Provider.of<DatabaseService>(context, listen: false).getFarms();
    if (farms.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create farm. Please try again.')),
        );
      }
      return;
    }

    // Use the first farm's ID
    final farmId = farms.first['id'];

    final sampleTasks = [
      {
        'farm_id': farmId,
        'title': 'Prepare soil for spring planting',
        'description': 'Test soil pH and nutrient levels, add necessary amendments',
        'priority': 'High',
        'status': 'Pending',
        'category': 'Planting',
        'due_date': DateTime.now().add(const Duration(days: 5)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Irrigation system maintenance',
        'description': 'Check and repair sprinklers, clean filters, test water pressure',
        'priority': 'Medium',
        'status': 'In Progress',
        'category': 'Maintenance',
        'due_date': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Harvest tomatoes',
        'description': 'Pick ripe tomatoes, sort by size and quality',
        'priority': 'High',
        'status': 'Pending',
        'category': 'Harvesting',
        'due_date': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Apply organic fertilizer',
        'description': 'Spread compost and organic fertilizer in the north field',
        'priority': 'Medium',
        'status': 'Pending',
        'category': 'Fertilization',
        'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Pest control inspection',
        'description': 'Check for signs of pests and apply preventive measures',
        'priority': 'Low',
        'status': 'Pending',
        'category': 'Maintenance',
        'due_date': DateTime.now().add(const Duration(days: 4)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Prune fruit trees',
        'description': 'Winter pruning of apple and pear trees',
        'priority': 'Medium',
        'status': 'Completed',
        'category': 'Maintenance',
        'due_date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Install new greenhouse',
        'description': 'Assemble and set up new greenhouse structure',
        'priority': 'High',
        'status': 'In Progress',
        'category': 'Maintenance',
        'due_date': DateTime.now().add(const Duration(days: 10)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'farm_id': farmId,
        'title': 'Order new seeds',
        'description': 'Place order for next season\'s seeds and supplies',
        'priority': 'Low',
        'status': 'Pending',
        'category': 'Planting',
        'due_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }
    ];

    try {
      for (final task in sampleTasks) {
        print('Inserting task: $task'); // Debug print
        await Provider.of<DatabaseService>(context, listen: false).insertTask(task);
      }
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample tasks added successfully')),
        );
      }
    } catch (e) {
      print('Error details: $e'); // Debug print
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding sample tasks: $e')),
        );
      }
    }
  }
} 