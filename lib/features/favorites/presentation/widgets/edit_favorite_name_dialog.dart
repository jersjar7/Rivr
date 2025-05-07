// lib/features/favorites/presentation/widgets/edit_favorite_name_dialog.dart

import 'package:flutter/material.dart';
import 'package:rivr/core/di/service_locator.dart';
import 'package:rivr/core/services/stream_name_service.dart';

/// Dialog for editing the name of a favorite river
/// Integrates with StreamNameService for consistent name management
class EditFavoriteNameDialog extends StatefulWidget {
  final String currentName;
  final String stationId;

  // originalApiName is optional since we'll try to get it from StreamNameService
  final String? originalApiName;

  const EditFavoriteNameDialog({
    super.key,
    required this.currentName,
    required this.stationId,
    this.originalApiName,
  });

  @override
  State<EditFavoriteNameDialog> createState() => _EditFavoriteNameDialogState();
}

class _EditFavoriteNameDialogState extends State<EditFavoriteNameDialog> {
  late TextEditingController _nameController;
  late StreamNameService _streamNameService;

  bool _isLoading = true;
  String? _originalName;
  bool _hasCustomName = false;

  @override
  void initState() {
    super.initState();
    // Initialize with current name
    _nameController = TextEditingController(text: widget.currentName);

    // Get StreamNameService instance
    _streamNameService = sl<StreamNameService>();

    // Load name information
    _loadNameInfo();
  }

  /// Load name information from StreamNameService
  Future<void> _loadNameInfo() async {
    setState(() => _isLoading = true);

    try {
      // Get name info from service
      final nameInfo = await _streamNameService.getNameInfo(widget.stationId);

      // Update state
      setState(() {
        // Use originalApiName from widget if provided, otherwise use from service
        _originalName = widget.originalApiName ?? nameInfo.originalApiName;
        _hasCustomName =
            _originalName != null &&
            _originalName!.isNotEmpty &&
            widget.currentName != _originalName;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading name info: $e');

      // Fall back to originalApiName from widget
      setState(() {
        _originalName = widget.originalApiName;
        _hasCustomName =
            _originalName != null &&
            _originalName!.isNotEmpty &&
            widget.currentName != _originalName;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Edit River Name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Customize the name for this river:',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'River Name',
              border: OutlineInputBorder(),
              hintText: 'Enter custom name',
            ),
            autofocus: true,
            maxLength: 50, // Reasonable character limit
          ),

          // Loading indicator while fetching original name
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading river information...',
                    style: TextStyle(fontSize: 12, color: theme.primaryColor),
                  ),
                ],
              ),
            ),

          // Show original name info if this is a custom name
          if (!_isLoading && _hasCustomName && _originalName != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This river has a custom name. Original name: "$_originalName"',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.primaryColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),

        // Show reset button if this is a custom name and we have an original name
        if (!_isLoading && _hasCustomName && _originalName != null)
          TextButton(
            onPressed: () async {
              // Update name in StreamNameService to the original API name
              if (_originalName != null) {
                await _streamNameService.resetToOriginalName(widget.stationId);
              }

              // Return the original name to the caller
              Navigator.of(context).pop(_originalName);
            },
            child: const Text('Reset to Default'),
          ),

        ElevatedButton(
          onPressed:
              _isLoading
                  ? null // Disable button while loading
                  : () async {
                    final newName = _nameController.text.trim();

                    // Don't allow empty names
                    if (newName.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid name'),
                        ),
                      );
                      return;
                    }

                    // Update the name in StreamNameService
                    if (newName != widget.currentName) {
                      await _streamNameService.updateDisplayName(
                        widget.stationId,
                        newName,
                      );
                    }

                    // Return the new name to the caller
                    Navigator.of(context).pop(newName);
                  },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Show the edit favorite name dialog
/// Returns the new name if saved, the original name if reset, or null if canceled
Future<String?> showEditFavoriteNameDialog(
  BuildContext context, {
  required String currentName,
  required String stationId,
  String? originalApiName,
}) {
  return showDialog<String>(
    context: context,
    builder:
        (context) => EditFavoriteNameDialog(
          currentName: currentName,
          stationId: stationId,
          originalApiName: originalApiName,
        ),
  );
}
