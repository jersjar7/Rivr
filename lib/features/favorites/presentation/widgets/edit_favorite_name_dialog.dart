// lib/features/favorites/presentation/widgets/edit_favorite_name_dialog.dart

import 'package:flutter/material.dart';

class EditFavoriteNameDialog extends StatefulWidget {
  final String currentName;
  final String stationId;

  const EditFavoriteNameDialog({
    super.key,
    required this.currentName,
    required this.stationId,
  });

  @override
  State<EditFavoriteNameDialog> createState() => _EditFavoriteNameDialogState();
}

class _EditFavoriteNameDialogState extends State<EditFavoriteNameDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Initialize with current name or "Untitled Stream" if empty
    final initialName =
        widget.currentName.isEmpty ? 'Untitled Stream' : widget.currentName;
    _nameController = TextEditingController(text: initialName);
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
          if (widget.currentName.startsWith('Station ') ||
              widget.currentName.isEmpty)
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
                      'This river has no official name. Your custom name will be saved locally.',
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
        ElevatedButton(
          onPressed: () {
            final newName = _nameController.text.trim();
            if (newName.isEmpty) {
              // Default to "Untitled Stream" if empty
              Navigator.of(context).pop('Untitled Stream');
            } else {
              Navigator.of(context).pop(newName);
            }
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
