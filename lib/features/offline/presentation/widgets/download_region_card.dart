// lib/features/offline/presentation/widgets/download_region_card.dart

import 'package:flutter/material.dart';

class DownloadRegionCard extends StatelessWidget {
  final VoidCallback onDownloadCurrentRegion;
  final VoidCallback onDownloadFavoriteAreas;
  final VoidCallback onDownloadCustomArea;

  const DownloadRegionCard({
    super.key,
    required this.onDownloadCurrentRegion,
    required this.onDownloadFavoriteAreas,
    required this.onDownloadCustomArea,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.download_rounded, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Download for Offline Use',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDownloadOption(
              context,
              'Current Map Region',
              'Download the area currently visible on your map',
              Icons.crop_free,
              onDownloadCurrentRegion,
            ),
            const Divider(),
            _buildDownloadOption(
              context,
              'Favorite Areas',
              'Download all your favorite river locations',
              Icons.favorite,
              onDownloadFavoriteAreas,
            ),
            const Divider(),
            _buildDownloadOption(
              context,
              'Custom Area',
              'Select a specific region to download',
              Icons.edit_location_alt,
              onDownloadCustomArea,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
