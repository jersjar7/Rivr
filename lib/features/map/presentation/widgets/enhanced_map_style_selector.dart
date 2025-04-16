// lib/presentation/widgets/enhanced_map_style_selector.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/constants/map_constants.dart';

class EnhancedMapStyleSelector extends StatelessWidget {
  final String currentStyle;
  final Function(String) onStyleSelected;

  const EnhancedMapStyleSelector({
    super.key,
    required this.currentStyle,
    required this.onStyleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // // Handle bar
          // Container(
          //   margin: const EdgeInsets.only(top: 12),
          //   width: 40,
          //   height: 4,
          //   decoration: BoxDecoration(
          //     color: Colors.grey[300],
          //     borderRadius: BorderRadius.circular(2),
          //   ),
          // ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 24, 1),
            child: Row(
              children: [
                const Text(
                  'Choose Map',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Style options grid
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStyleCard(
                  context,
                  'Standard',
                  MapConstants.mapboxStandard,
                  'assets/map_previews/standard.png',
                  Icons.public,
                ),
                _buildStyleCard(
                  context,
                  'Streets',
                  MapConstants.mapboxStreets,
                  'assets/map_previews/streets.png',
                  Icons.map,
                ),
                _buildStyleCard(
                  context,
                  'Outdoors',
                  MapConstants.mapboxOutdoors,
                  'assets/map_previews/outdoors.png',
                  Icons.terrain,
                ),
                _buildStyleCard(
                  context,
                  'Satellite',
                  MapConstants.mapboxSatelliteStreets,
                  'assets/map_previews/satellite_streets.png',
                  Icons.satellite_alt,
                ),
                _buildStyleCard(
                  context,
                  'Light',
                  MapConstants.mapboxLight,
                  'assets/map_previews/light.png',
                  Icons.light_mode,
                ),
                _buildStyleCard(
                  context,
                  'Dark',
                  MapConstants.mapboxDark,
                  'assets/map_previews/dark.png',
                  Icons.dark_mode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleCard(
    BuildContext context,
    String title,
    String styleUri,
    String imagePath,
    IconData iconData,
  ) {
    final bool isSelected = currentStyle == styleUri;
    final Color primaryColor = Theme.of(context).primaryColor;
    final borderRadius = BorderRadius.circular(12);

    return GestureDetector(
      onTap: () => onStyleSelected(styleUri),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview Image with rounded corners
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image preview
                  Container(
                    // margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                      // border: Border.all(color: Colors.grey[300]!, width: 1),
                      image: DecorationImage(
                        image: AssetImage(imagePath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title at the bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 6, top: 6, left: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 6),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w400,
                      color: isSelected ? primaryColor : Colors.black87,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
