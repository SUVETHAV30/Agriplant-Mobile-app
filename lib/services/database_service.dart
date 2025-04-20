import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class DatabaseService extends ChangeNotifier {
  static Database? _database;
  static SharedPreferences? _prefs;
  static const String _dbName = 'agriplant.db';
  static const String _prefsKey = 'agriplant_data';

  Future<dynamic> get database async {
    if (kIsWeb) {
      if (_prefs == null) {
        await _initializeWebStorage();
      }
      return _prefs;
    } else {
      if (_database == null) {
        await _initializeSqliteDatabase();
      }
      return _database;
    }
  }

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _error;
  String? get error => _error;

  // Tables
  static const String tableFarms = 'farms';
  static const String tableCrops = 'crops';
  static const String tableTasks = 'tasks';
  static const String tableWeather = 'weather';
  static const String tableNotifications = 'notifications';

  Future<void> initialize() async {
    try {
      await database;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _error = 'Error initializing database: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _initializeWebStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!_prefs!.containsKey(_prefsKey)) {
        await _prefs!.setString(_prefsKey, json.encode({
          tableFarms: [],
          tableCrops: [],
          tableTasks: [],
          tableWeather: [],
          tableNotifications: [],
        }));
      }
    } catch (e) {
      print('Error initializing web storage: $e');
      rethrow;
    }
  }

  Future<void> _initializeSqliteDatabase() async {
    try {
      final path = join(await getDatabasesPath(), _dbName);
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createSqliteTables,
      );
    } catch (e) {
      print('Error initializing SQLite database: $e');
      rethrow;
    }
  }

  Future<void> _createSqliteTables(Database db, int version) async {
    try {
      // Create farms table first
      await db.execute('''
        CREATE TABLE IF NOT EXISTS farms(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          location TEXT NOT NULL,
          area REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // Create tasks table with proper foreign key and default values
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tasks(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          farm_id INTEGER NOT NULL DEFAULT 1,
          title TEXT NOT NULL,
          description TEXT,
          priority TEXT NOT NULL DEFAULT 'Medium',
          due_date TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'Pending',
          category TEXT NOT NULL DEFAULT 'General',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (farm_id) REFERENCES farms(id) ON DELETE SET DEFAULT
        )
      ''');

      await db.execute('''
        CREATE TABLE crops(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          farm_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          type TEXT NOT NULL,
          planting_date TEXT NOT NULL,
          harvest_date TEXT,
          status TEXT NOT NULL,
          FOREIGN KEY (farm_id) REFERENCES farms (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE task_attachments(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          file_path TEXT NOT NULL,
          file_name TEXT NOT NULL,
          file_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE task_dependencies(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          task_id INTEGER NOT NULL,
          dependent_task_id INTEGER NOT NULL,
          dependency_type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
          FOREIGN KEY (dependent_task_id) REFERENCES tasks (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE weather(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          farm_id INTEGER NOT NULL,
          temperature REAL NOT NULL,
          humidity REAL NOT NULL,
          rainfall REAL NOT NULL,
          wind_speed REAL NOT NULL,
          recorded_at TEXT NOT NULL,
          FOREIGN KEY (farm_id) REFERENCES farms (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE notifications(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT NOT NULL,
          created_at TEXT NOT NULL,
          read BOOLEAN NOT NULL DEFAULT 0
        )
      ''');
    } catch (e) {
      print('Error creating tables: $e');
      rethrow;
    }
  }

  // Generic CRUD operations for both platforms
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    try {
      if (kIsWeb) {
        final prefs = db as SharedPreferences;
        final allData = json.decode(prefs.getString(_prefsKey) ?? '{}');
        final tableData = List<Map<String, dynamic>>.from(allData[table] ?? []);
        final newId = tableData.isEmpty ? 1 : (tableData.last['id'] as int) + 1;
        data['id'] = newId;
        tableData.add(data);
        allData[table] = tableData;
        await prefs.setString(_prefsKey, json.encode(allData));
        return newId;
      } else {
        print('Inserting into $table with data: $data'); // Debug print
        final result = await (db as Database).insert(table, data);
        print('Insert result: $result'); // Debug print
        return result;
      }
    } catch (e) {
      print('Error inserting into $table: $e'); // Debug print
      print('Data being inserted: $data'); // Debug print
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> query(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    try {
      if (kIsWeb) {
        final prefs = db as SharedPreferences;
        final allData = json.decode(prefs.getString(_prefsKey) ?? '{}');
        final tableData = List<Map<String, dynamic>>.from(allData[table] ?? []);
        if (where != null && whereArgs != null) {
          return tableData.where((item) {
            final field = where.split(' = ?')[0];
            return item[field] == whereArgs[0];
          }).toList();
        }
        return tableData;
      } else {
        print('Querying $table with where: $where, args: $whereArgs'); // Debug print
        final result = await (db as Database).query(table, where: where, whereArgs: whereArgs);
        print('Query result: $result'); // Debug print
        return result;
      }
    } catch (e) {
      print('Error querying $table: $e'); // Debug print
      rethrow;
    }
  }

  Future<int> update(String table, Map<String, dynamic> data, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final allData = json.decode(prefs.getString(_prefsKey) ?? '{}');
      final tableData = List<Map<String, dynamic>>.from(allData[table] ?? []);
      final index = tableData.indexWhere((item) => item['id'] == whereArgs?[0]);
      if (index != -1) {
        tableData[index] = {...tableData[index], ...data};
        allData[table] = tableData;
        await prefs.setString(_prefsKey, json.encode(allData));
        return 1;
      }
      return 0;
    } else {
      return await (db as Database).update(table, data, where: where, whereArgs: whereArgs);
    }
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    if (kIsWeb) {
      final prefs = db as SharedPreferences;
      final allData = json.decode(prefs.getString(_prefsKey) ?? '{}');
      final tableData = List<Map<String, dynamic>>.from(allData[table] ?? []);
      tableData.removeWhere((item) => item['id'] == whereArgs?[0]);
      allData[table] = tableData;
      await prefs.setString(_prefsKey, json.encode(allData));
      return 1;
    } else {
      return await (db as Database).delete(table, where: where, whereArgs: whereArgs);
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
    notifyListeners();
  }

  // Farm operations
  Future<int> insertFarm(Map<String, dynamic> farm) async {
    return await insert(tableFarms, farm);
  }

  Future<List<Map<String, dynamic>>> getFarms() async {
    return await query(tableFarms);
  }

  Future<Map<String, dynamic>?> getFarm(int id) async {
    final List<Map<String, dynamic>> maps = await query(
      tableFarms,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<int> updateFarm(Map<String, dynamic> farm) async {
    return await update(tableFarms, farm);
  }

  Future<int> deleteFarm(int id) async {
    return await delete(tableFarms, whereArgs: [id]);
  }

  // Crop operations
  Future<int> insertCrop(Map<String, dynamic> crop) async {
    return await insert(tableCrops, crop);
  }

  Future<List<Map<String, dynamic>>> getCrops(int farmId) async {
    return await query(
      tableCrops,
      where: 'farm_id = ?',
      whereArgs: [farmId],
    );
  }

  // Task operations
  Future<int> insertTask(Map<String, dynamic> task) async {
    try {
      print('Inserting task: $task'); // Debug print
      
      // Ensure farm_id is an integer
      if (task['farm_id'] is String) {
        task['farm_id'] = int.parse(task['farm_id']);
      }

      // If no farm_id provided, try to get the first farm
      if (task['farm_id'] == null) {
        final farms = await getFarms();
        if (farms.isEmpty) {
          // Create a default farm if none exists
          final defaultFarm = {
            'name': 'Default Farm',
            'location': 'Default Location',
            'area': 100.0,
            'created_at': DateTime.now().toIso8601String(),
          };
          final farmId = await insertFarm(defaultFarm);
          task['farm_id'] = farmId;
        } else {
          task['farm_id'] = farms.first['id'];
        }
      }

      // Verify farm exists
      final farm = await getFarm(task['farm_id']);
      if (farm == null) {
        throw Exception('Farm with ID ${task['farm_id']} does not exist');
      }

      // Add required fields with defaults
      final now = DateTime.now().toIso8601String();
      task['created_at'] = task['created_at'] ?? now;
      task['updated_at'] = task['updated_at'] ?? now;
      task['status'] = task['status'] ?? 'Pending';
      task['priority'] = task['priority'] ?? 'Medium';
      task['category'] = task['category'] ?? 'General';

      // Ensure due_date is set
      if (task['due_date'] == null) {
        task['due_date'] = now;
      }

      print('Final task data: $task'); // Debug print
      return await insert(tableTasks, task);
    } catch (e) {
      print('Error inserting task: $e'); // Debug print
      print('Task data: $task'); // Debug print
      rethrow;
    }
  }

  Future<int> insertTaskAttachment(Map<String, dynamic> attachment) async {
    return await insert('task_attachments', attachment);
  }

  Future<int> insertTaskDependency(Map<String, dynamic> dependency) async {
    return await insert('task_dependencies', dependency);
  }

  Future<List<Map<String, dynamic>>> getTasks({int? farmId}) async {
    try {
      if (farmId != null) {
        return await query(
          tableTasks,
          where: 'farm_id = ?',
          whereArgs: [farmId],
        );
      }
      return await query(tableTasks);
    } catch (e) {
      print('Error getting tasks: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getTaskAttachments(int taskId) async {
    return await query(
      'task_attachments',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<Map<String, dynamic>>> getTaskDependencies(int taskId) async {
    return await query(
      'task_dependencies',
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<List<Map<String, dynamic>>> getDependentTasks(int taskId) async {
    return await query(
      'task_dependencies',
      where: 'dependent_task_id = ?',
      whereArgs: [taskId],
    );
  }

  Future<Map<String, dynamic>?> getTask(int id) async {
    try {
      final List<Map<String, dynamic>> maps = await query(
        tableTasks,
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return maps.first;
      }
      return null;
    } catch (e) {
      print('Error getting task: $e');
      rethrow;
    }
  }

  Future<int> updateTask(Map<String, dynamic> task) async {
    try {
      // Ensure farm_id is an integer
      if (task['farm_id'] is String) {
        task['farm_id'] = int.parse(task['farm_id']);
      }

      // Verify farm exists
      final farm = await getFarm(task['farm_id']);
      if (farm == null) {
        throw Exception('Farm with ID ${task['farm_id']} does not exist');
      }

      // Update the updated_at timestamp
      task['updated_at'] = DateTime.now().toIso8601String();

      return await update(tableTasks, task);
    } catch (e) {
      print('Error updating task: $e');
      rethrow;
    }
  }

  Future<int> deleteTask(int id) async {
    return await delete(tableTasks, whereArgs: [id]);
  }

  Future<int> deleteTaskAttachment(int id) async {
    return await delete('task_attachments', whereArgs: [id]);
  }

  Future<int> deleteTaskDependency(int id) async {
    return await delete('task_dependencies', whereArgs: [id]);
  }

  // Weather operations
  Future<int> insertWeather(Map<String, dynamic> weather) async {
    return await insert(tableWeather, weather);
  }

  Future<List<Map<String, dynamic>>> getWeatherHistory(int farmId) async {
    final results = await query(
      tableWeather,
      where: 'farm_id = ?',
      whereArgs: [farmId],
    );
    
    if (kIsWeb) {
      return results..sort((a, b) => b['recorded_at'].compareTo(a['recorded_at']));
    }
    return results;
  }

  // Notification operations
  Future<int> insertNotification(Map<String, dynamic> notification) async {
    return await insert(tableNotifications, notification);
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final results = await query(tableNotifications);
    if (kIsWeb) {
      return results..sort((a, b) => b['created_at'].compareTo(a['created_at']));
    }
    return results;
  }

  Future<void> markNotificationAsRead(int id) async {
    await update(tableNotifications, {'read': 1}, whereArgs: [id]);
  }
} 