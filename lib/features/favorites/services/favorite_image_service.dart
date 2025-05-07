// lib/features/favorites/services/favorite_image_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart'; // Add this package to pubspec.yaml

class FavoriteImageService {
  static const String _customImagesDir = 'custom_river_images';
  static final _uuid = Uuid();

  // Get the directory for storing custom images
  static Future<Directory> _getImagesDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(directory.path, _customImagesDir));

    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    return imagesDir;
  }

  // Save an image for a favorite
  static Future<String> saveImage({
    required String userId,
    required String stationId,
    required List<int> bytes,
  }) async {
    try {
      final imagesDir = await _getImagesDirectory();
      final imageId = _uuid.v4();
      final fileName = '${userId}_${stationId}_$imageId.jpg';
      final filePath = path.join(imagesDir.path, fileName);

      // Save the file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return fileName; // Return the file name for reference
    } catch (e) {
      debugPrint('Error saving favorite image: $e');
      rethrow;
    }
  }

  // Get the path to an image
  static Future<String?> getImagePath(String fileName) async {
    try {
      final imagesDir = await _getImagesDirectory();
      final filePath = path.join(imagesDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        return filePath;
      }

      return null;
    } catch (e) {
      debugPrint('Error getting favorite image: $e');
      return null;
    }
  }

  // Delete an image
  static Future<bool> deleteImage(String fileName) async {
    try {
      final imagesDir = await _getImagesDirectory();
      final filePath = path.join(imagesDir.path, fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error deleting favorite image: $e');
      return false;
    }
  }

  // Clear all images
  static Future<int> clearAllImages() async {
    try {
      final imagesDir = await _getImagesDirectory();
      final files = await imagesDir.list().toList();

      int count = 0;
      for (final file in files) {
        if (file is File) {
          await file.delete();
          count++;
        }
      }

      return count;
    } catch (e) {
      debugPrint('Error clearing all favorite images: $e');
      return 0;
    }
  }
}
