// lib/features/favorites/presentation/widgets/edit_favorite_name_dialog.dart

import 'package:flutter/material.dart';

class EditFavoriteNameDialog extends StatefulWidget {
  final String currentName;
  final String stationId;
  final String? originalApiName; // Added parameter

  const EditFavoriteNameDialog({
    super.key,
    required this.currentName,
    required this.stationId,
    this.originalApiName, // New parameter
  });

  @override
  State<EditFavoriteNameDialog> createState() => _EditFavoriteNameDialogState();
}

class _EditFavoriteNameDialogState extends State<EditFavoriteNameDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Initialize with current name, even if it's empty
    _nameController = TextEditingController(text: widget.currentName);
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
          if (widget.originalApiName != null &&
              widget.currentName != widget.originalApiName)
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
                      'This river has a custom name. Original name: "${widget.originalApiName}"',
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
        if (widget.originalApiName != null &&
            widget.currentName != widget.originalApiName)
          TextButton(
            onPressed: () => Navigator.of(context).pop(widget.originalApiName),
            child: const Text('Reset to Default'),
          ),
        ElevatedButton(
          onPressed: () {
            final newName = _nameController.text.trim();
            // Return the name as-is, even if empty
            Navigator.of(context).pop(newName);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
