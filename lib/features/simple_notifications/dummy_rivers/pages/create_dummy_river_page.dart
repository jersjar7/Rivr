import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dummy_river.dart';
import '../providers/dummy_rivers_provider.dart';
import '../widgets/return_period_editor.dart';

class CreateDummyRiverPage extends StatefulWidget {
  final DummyRiver? existingRiver;

  const CreateDummyRiverPage({super.key, this.existingRiver});

  @override
  State<CreateDummyRiverPage> createState() => _CreateDummyRiverPageState();
}

class _CreateDummyRiverPageState extends State<CreateDummyRiverPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool get isEditing => widget.existingRiver != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final formProvider = context.read<DummyRiverFormProvider>();

      if (isEditing) {
        // Load existing river data
        formProvider.loadFromDummyRiver(widget.existingRiver!);
        _nameController.text = widget.existingRiver!.name;
        _descriptionController.text = widget.existingRiver!.description;
      } else {
        // Reset form for new river
        formProvider.reset();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Dummy River' : 'Create Dummy River'),
        actions: [
          if (!isEditing)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'load_defaults',
                      child: Row(
                        children: [
                          Icon(Icons.auto_fix_high),
                          SizedBox(width: 8),
                          Text('Load Defaults'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'reset_form',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all),
                          SizedBox(width: 8),
                          Text('Reset Form'),
                        ],
                      ),
                    ),
                  ],
            ),
        ],
      ),
      body: Consumer<DummyRiverFormProvider>(
        builder: (context, formProvider, child) {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                // Error display
                if (formProvider.hasValidationErrors)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.red.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Please fix the following errors:',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...formProvider.validationErrors.map(
                          (error) => Padding(
                            padding: const EdgeInsets.only(left: 32, bottom: 4),
                            child: Text(
                              '• $error',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information Section
                        _buildSectionCard(
                          title: 'Basic Information',
                          icon: Icons.info_outline,
                          children: [
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'River Name *',
                                hintText: 'e.g., Test River 1',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'River name is required';
                                }
                                if (value.length > 100) {
                                  return 'Name must be 100 characters or less';
                                }
                                return null;
                              },
                              onChanged: formProvider.updateName,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                hintText:
                                    'Optional description for this test river',
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 3,
                              validator: (value) {
                                if (value != null && value.length > 500) {
                                  return 'Description must be 500 characters or less';
                                }
                                return null;
                              },
                              onChanged: formProvider.updateDescription,
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              value: formProvider.unit,
                              decoration: const InputDecoration(
                                labelText: 'Flow Unit *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'cfs',
                                  child: Text(
                                    'CFS (Cubic Feet per Second)',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'cms',
                                  child: Text(
                                    'CMS (Cubic Meters per Second)',
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                                // DropdownMenuItem(
                                //   value: 'm3/s',
                                //   child: Text('m³/s (Cubic Meters per Second)'),
                                // ),
                                // DropdownMenuItem(
                                //   value: 'ft3/s',
                                //   child: Text('ft³/s (Cubic Feet per Second)'),
                                // ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  formProvider.updateUnit(value);
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a flow unit';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Return Periods Section
                        _buildSectionCard(
                          title: 'Return Periods',
                          icon: Icons.show_chart,
                          children: [
                            Text(
                              'Define flow values for different return periods. Higher return periods should have higher flow values.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            ReturnPeriodEditor(
                              returnPeriods: formProvider.returnPeriods,
                              unit: formProvider.unit,
                              onReturnPeriodChanged:
                                  formProvider.updateReturnPeriod,
                              onReturnPeriodRemoved:
                                  formProvider.removeReturnPeriod,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: Theme.of(context).dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: formProvider.isSubmitting ? null : _cancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed:
                              formProvider.isSubmitting ? null : _saveRiver,
                          child:
                              formProvider.isSubmitting
                                  ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Text('Saving...'),
                                    ],
                                  )
                                  : Text(
                                    isEditing ? 'Save Changes' : 'Create River',
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  void _handleMenuAction(String action) {
    final formProvider = context.read<DummyRiverFormProvider>();

    switch (action) {
      case 'load_defaults':
        _loadDefaults(formProvider);
        break;
      case 'reset_form':
        _resetForm(formProvider);
        break;
    }
  }

  void _loadDefaults(DummyRiverFormProvider formProvider) {
    formProvider.loadDefaults();
    _nameController.text = formProvider.name;
    _descriptionController.text = formProvider.description;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Default values loaded'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _resetForm(DummyRiverFormProvider formProvider) {
    formProvider.reset();
    _nameController.clear();
    _descriptionController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Form reset'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancel() {
    if (_hasUnsavedChanges()) {
      showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Discard Changes?'),
              content: const Text(
                'You have unsaved changes. Are you sure you want to leave?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true);
                    Navigator.of(context).pop(); // Close this page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Discard'),
                ),
              ],
            ),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  bool _hasUnsavedChanges() {
    final formProvider = context.read<DummyRiverFormProvider>();

    if (isEditing) {
      // Check if any field has changed from the original
      return _nameController.text != widget.existingRiver!.name ||
          _descriptionController.text != widget.existingRiver!.description ||
          formProvider.unit != widget.existingRiver!.unit ||
          !_mapsEqual(
            formProvider.returnPeriods,
            widget.existingRiver!.returnPeriods,
          );
    } else {
      // Check if any field has been filled
      return _nameController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          formProvider.returnPeriods.isNotEmpty;
    }
  }

  bool _mapsEqual(Map<int, double> map1, Map<int, double> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  Future<void> _saveRiver() async {
    // Clear previous validation errors
    final formProvider = context.read<DummyRiverFormProvider>();
    formProvider.setValidationErrors([]);

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if return periods are defined
    if (formProvider.returnPeriods.isEmpty) {
      formProvider.setValidationErrors([
        'At least one return period is required',
      ]);
      return;
    }

    formProvider.setSubmitting(true);

    try {
      final dummyRiversProvider = context.read<DummyRiversProvider>();

      if (isEditing) {
        // Update existing river
        final updatedRiver = formProvider.toDummyRiver(
          id: widget.existingRiver!.id,
        );
        final success = await dummyRiversProvider.updateDummyRiver(
          updatedRiver,
        );

        if (success) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('River updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          // Error is already set in provider
          formProvider.setValidationErrors([
            dummyRiversProvider.error ?? 'Failed to update river',
          ]);
        }
      } else {
        // Create new river
        final newRiver = formProvider.toDummyRiver();
        final riverId = await dummyRiversProvider.createDummyRiver(newRiver);

        if (riverId != null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('River created successfully'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
        } else {
          // Error is already set in provider
          formProvider.setValidationErrors([
            dummyRiversProvider.error ?? 'Failed to create river',
          ]);
        }
      }
    } catch (e) {
      formProvider.setValidationErrors(['An unexpected error occurred: $e']);
    } finally {
      formProvider.setSubmitting(false);
    }
  }
}
