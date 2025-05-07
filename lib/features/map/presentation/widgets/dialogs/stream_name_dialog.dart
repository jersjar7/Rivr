// lib/features/map/presentation/widgets/dialogs/stream_name_dialog.dart

import 'package:flutter/material.dart';

/// Dialog for inputting a custom stream name
class StreamNameDialog extends StatefulWidget {
  final String? initialName;
  final String? stationId;

  const StreamNameDialog({super.key, this.initialName, this.stationId});

  @override
  State<StreamNameDialog> createState() => _StreamNameDialogState();
}

class _StreamNameDialogState extends State<StreamNameDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    // Use initial name if provided, otherwise empty
    _nameController = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Name This Stream'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.stationId != null
                ? 'This stream does not have a name. Please assign a name for your device\'s use:'
                : 'Enter a custom name for this stream:',
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Enter a name for this stream',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLength: 100,
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
            // Validate input - don't allow empty names
            if (_nameController.text.trim().isNotEmpty) {
              Navigator.of(context).pop(_nameController.text.trim());
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a name')),
              );
            }
          },
          child: const Text('Save Name'),
        ),
      ],
    );
  }
}
