// lib/features/map/presentation/widgets/map_components/style_selector_sheet.dart

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Bottom sheet for selecting map styles
class StyleSelectorSheet extends StatelessWidget {
  final String currentStyle;
  final Function(String) onStyleSelected;

  const StyleSelectorSheet({
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
            color: Colors.black.withAlpha(26),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 24, 8),
            child: Row(
              children: [
                const Text(
                  'Choose Map Style',
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
                  MapboxStyles.STANDARD,
                  Icons.public,
                ),
                _buildStyleCard(
                  context,
                  'Streets',
                  MapboxStyles.MAPBOX_STREETS,
                  Icons.map,
                ),
                _buildStyleCard(
                  context,
                  'Outdoors',
                  MapboxStyles.OUTDOORS,
                  Icons.terrain,
                ),
                _buildStyleCard(
                  context,
                  'Satellite',
                  MapboxStyles.SATELLITE_STREETS,
                  Icons.satellite_alt,
                ),
                _buildStyleCard(
                  context,
                  'Light',
                  MapboxStyles.LIGHT,
                  Icons.light_mode,
                ),
                _buildStyleCard(
                  context,
                  'Dark',
                  MapboxStyles.DARK,
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
    IconData iconData,
  ) {
    final bool isSelected = currentStyle == styleUri;
    final Color primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => onStyleSelected(styleUri),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: primaryColor.withAlpha(77),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: 48,
              color: isSelected ? primaryColor : Colors.grey[700],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? primaryColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
