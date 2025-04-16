// lib/features/map/presentation/widgets/enhanced_map_style_selector.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/map_constants.dart';

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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                const Text(
                  'Choose Map Style',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
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
                  'Streets',
                  MapConstants.mapboxStreets,
                  Icons.map,
                ),
                _buildStyleCard(
                  context,
                  'Outdoors',
                  MapConstants.mapboxOutdoors,
                  Icons.terrain,
                ),
                _buildStyleCard(
                  context,
                  'Satellite',
                  MapConstants.mapboxSatelliteStreets,
                  Icons.satellite_alt,
                ),
                _buildStyleCard(
                  context,
                  'Standard',
                  MapConstants.mapboxStandard,
                  Icons.public,
                ),
                _buildStyleCard(
                  context,
                  'Light',
                  MapConstants.mapboxLight,
                  Icons.light_mode,
                ),
                _buildStyleCard(
                  context,
                  'Dark',
                  MapConstants.mapboxDark,
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
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Preview Icon with style
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Style icon background
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      color:
                          isSelected
                              ? primaryColor.withOpacity(0.05)
                              : Colors.grey[100],
                    ),
                    child: Center(
                      child: Icon(
                        iconData,
                        size: 48,
                        color: isSelected ? primaryColor : Colors.grey[700],
                      ),
                    ),
                  ),

                  // Selected overlay with icon
                  if (isSelected)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Title at the bottom
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.radio_button_checked,
                      color: primaryColor,
                      size: 14,
                    )
                  else
                    Icon(
                      Icons.radio_button_unchecked,
                      color: Colors.grey,
                      size: 14,
                    ),
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
