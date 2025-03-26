import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

abstract class AppDatabase {
  Future<Database> get database;
  Future<List<Map<String, dynamic>>> queryWithUserId(
    String table,
    String userId, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  });
}

class AppDatabaseImpl implements AppDatabase {
  static Database? _database;

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rivr.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Favorites table with userId
        await db.execute('''
          CREATE TABLE favorites(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stationId TEXT NOT NULL,
            name TEXT NOT NULL,
            userId TEXT NOT NULL,
            position INTEGER NOT NULL,
            color TEXT,
            description TEXT,
            imgNumber INTEGER,
            lastUpdated INTEGER NOT NULL,
            UNIQUE(stationId, userId)
          )
        ''');

        // Stations table
        await db.execute('''
          CREATE TABLE stations(
            stationId TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            lastUpdated INTEGER NOT NULL
          )
        ''');

        // Forecast cache
        await db.execute('''
          CREATE TABLE forecast_cache(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            stationId TEXT NOT NULL,
            userId TEXT NOT NULL,
            forecastType TEXT NOT NULL,
            data TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            UNIQUE(stationId, userId, forecastType)
          )
        ''');

        // User preferences
        await db.execute('''
          CREATE TABLE user_preferences(
            userId TEXT PRIMARY KEY,
            flowUnit TEXT DEFAULT 'cfs',
            theme TEXT DEFAULT 'light',
            notificationsEnabled INTEGER DEFAULT 1,
            lastSynced INTEGER NOT NULL
          )
        ''');

        // Notification settings
        await db.execute('''
          CREATE TABLE notification_settings(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT NOT NULL,
            stationId TEXT NOT NULL,
            thresholdType TEXT NOT NULL,
            thresholdValue REAL NOT NULL,
            enabled INTEGER DEFAULT 1,
            UNIQUE(userId, stationId, thresholdType)
          )
        ''');
      },
    );
  }

  @override
  Future<List<Map<String, dynamic>>> queryWithUserId(
    String table,
    String userId, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    final db = await database;
    final whereClause = where != null ? '$where AND userId = ?' : 'userId = ?';
    final args = [...?whereArgs, userId];

    return await db.query(
      table,
      where: whereClause,
      whereArgs: args,
      orderBy: orderBy,
    );
  }
}
