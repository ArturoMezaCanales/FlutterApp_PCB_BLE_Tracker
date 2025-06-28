import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'esp32_data_parser.dart';

class DatabaseService {
  static Database? _database;
  static const String tableName = 'gps_data';
  static const String webStorageKey = 'esp32_gps_data';

  static Future<Database?> get database async {
    // Return null for web platforms - we'll use SharedPreferences instead
    if (kIsWeb) return null;
    
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database?> _initDatabase() async {
    // Skip database initialization on web
    if (kIsWeb) return null;
    
    String path = join(await getDatabasesPath(), 'esp32_tracker.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            altitude REAL NOT NULL,
            rssi INTEGER NOT NULL,
            received_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  static Future<int> insertGPSData(ESP32Data data) async {
    if (kIsWeb) {
      // Use SharedPreferences for web storage
      return await _insertWebData(data);
    }
    
    final db = await database;
    if (db == null) return 0;
    
    Map<String, dynamic> dataMap = data.toMap();
    dataMap['received_at'] = DateTime.now().toIso8601String();
    
    return await db.insert(tableName, dataMap);
  }

  static Future<int> _insertWebData(ESP32Data data) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get existing data
    List<ESP32Data> existingData = await _getWebData();
    
    // Add new data
    existingData.add(data);
    
    // Keep only the last 100 entries to avoid storage overflow
    if (existingData.length > 100) {
      existingData = existingData.sublist(existingData.length - 100);
    }
    
    // Convert to JSON and save
    List<String> jsonData = existingData.map((item) => 
      jsonEncode({
        ...item.toMap(),
        'received_at': DateTime.now().toIso8601String(),
      })
    ).toList();
    
    await prefs.setStringList(webStorageKey, jsonData);
    return existingData.length;
  }

  static Future<List<ESP32Data>> _getWebData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonDataList = prefs.getStringList(webStorageKey) ?? [];
    
    return jsonDataList.map((jsonStr) {
      final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      return ESP32Data(
        timestamp: DateTime.parse(jsonMap['timestamp']),
        latitude: jsonMap['latitude'],
        longitude: jsonMap['longitude'],
        altitude: jsonMap['altitude'],
        rssi: jsonMap['rssi'],
      );
    }).toList();
  }

  static Future<List<ESP32Data>> getAllGPSData({int? limit}) async {
    if (kIsWeb) {
      // Use SharedPreferences for web storage
      List<ESP32Data> data = await _getWebData();
      if (limit != null && data.length > limit) {
        return data.sublist(0, limit);
      }
      return data;
    }
    
    final db = await database;
    if (db == null) return [];
    
    List<Map<String, dynamic>> maps;
    if (limit != null) {
      maps = await db.query(
        tableName,
        orderBy: 'id DESC',
        limit: limit,
      );
    } else {
      maps = await db.query(
        tableName,
        orderBy: 'id DESC',
      );
    }

    return List.generate(maps.length, (i) {
      return ESP32Data(
        timestamp: DateTime.parse(maps[i]['timestamp']),
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        altitude: maps[i]['altitude'],
        rssi: maps[i]['rssi'],
      );
    });
  }

  static Future<List<ESP32Data>> getGPSDataInRange(DateTime start, DateTime end) async {
    if (kIsWeb) {
      List<ESP32Data> data = await _getWebData();
      return data.where((item) => 
        item.timestamp.isAfter(start) && item.timestamp.isBefore(end)
      ).toList();
    }
    
    final db = await database;
    if (db == null) return [];
    
    List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    return List.generate(maps.length, (i) {
      return ESP32Data(
        timestamp: DateTime.parse(maps[i]['timestamp']),
        latitude: maps[i]['latitude'],
        longitude: maps[i]['longitude'],
        altitude: maps[i]['altitude'],
        rssi: maps[i]['rssi'],
      );
    });
  }

  static Future<int> getDataCount() async {
    if (kIsWeb) {
      List<ESP32Data> data = await _getWebData();
      return data.length;
    }
    
    final db = await database;
    if (db == null) return 0;
    
    var result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<ESP32Data?> getLatestData() async {
    if (kIsWeb) {
      List<ESP32Data> data = await _getWebData();
      return data.isNotEmpty ? data.first : null;
    }
    
    final db = await database;
    if (db == null) return null;
    
    List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'id DESC',
      limit: 1,
    );

    if (maps.isEmpty) return null;

    return ESP32Data(
      timestamp: DateTime.parse(maps[0]['timestamp']),
      latitude: maps[0]['latitude'],
      longitude: maps[0]['longitude'],
      altitude: maps[0]['altitude'],
      rssi: maps[0]['rssi'],
    );
  }

  static Future<void> clearOldData({int keepDays = 30}) async {
    if (kIsWeb) {
      List<ESP32Data> data = await _getWebData();
      DateTime cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
      
      List<ESP32Data> filteredData = data.where((item) => 
        item.timestamp.isAfter(cutoffDate)
      ).toList();
      
      final prefs = await SharedPreferences.getInstance();
      List<String> jsonData = filteredData.map((item) => 
        jsonEncode({
          ...item.toMap(),
          'received_at': DateTime.now().toIso8601String(),
        })
      ).toList();
      
      await prefs.setStringList(webStorageKey, jsonData);
      return;
    }
    
    final db = await database;
    if (db == null) return;
    
    DateTime cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    
    await db.delete(
      tableName,
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  static Future<void> deleteAllData() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(webStorageKey);
      return;
    }
    
    final db = await database;
    if (db != null) {
      await db.delete(tableName);
    }
  }

  static Future<void> close() async {
    if (kIsWeb) return; // No database to close on web
    
    final db = await database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
