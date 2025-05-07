// lib/common/data/local/database_migration_helper.dart

import 'package:sqflite/sqflite.dart';

class DatabaseMigrationHelper {
  /// Execute migrations for the database
  static Future<void> migrateFavoritesTable(Database db) async {
    try {
      // Check if customImagePath column exists
      final tableInfo = await db.rawQuery('PRAGMA table_info(favorites)');
      final hasCustomImagePathColumn = tableInfo.any(
        (column) => column['name'] == 'customImagePath',
      );
      final hasOriginalApiNameColumn = tableInfo.any(
        (column) => column['name'] == 'originalApiName',
      );

      // Add column if it doesn't exist
      if (!hasCustomImagePathColumn) {
        await db.execute(
          'ALTER TABLE favorites ADD COLUMN customImagePath TEXT',
        );
        print('Added customImagePath column to favorites table');
      }
      if (!hasOriginalApiNameColumn) {
        await db.execute(
          'ALTER TABLE favorites ADD COLUMN originalApiName TEXT',
        );
        print('Added originalApiName column to favorites table');

        // For existing records, set originalApiName to current name
        await db.execute(
          "UPDATE favorites SET originalApiName = name WHERE originalApiName IS NULL OR originalApiName = ''",
        );
        print('Updated existing favorites with originalApiName = name');

        await db.execute(
          "UPDATE favorites SET originalApiName = NULL WHERE originalApiName = 'null'",
        );
        print('Cleaned up "null" string values in originalApiName column');
      }
    } catch (e) {
      print('Error migrating database: $e');
      // Handle error appropriately - we may want to add more robust error handling
    }
  }

  /// Ensure all required migration steps are executed
  static Future<void> ensureMigrations(Database db) async {
    await migrateFavoritesTable(db);
    // Add other migrations as needed
  }
}
