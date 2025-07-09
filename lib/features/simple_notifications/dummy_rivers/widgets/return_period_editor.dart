import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ReturnPeriodEditor extends StatefulWidget {
  final Map<int, double> returnPeriods;
  final String unit;
  final Function(int year, double flow) onReturnPeriodChanged;
  final Function(int year) onReturnPeriodRemoved;

  const ReturnPeriodEditor({
    super.key,
    required this.returnPeriods,
    required this.unit,
    required this.onReturnPeriodChanged,
    required this.onReturnPeriodRemoved,
  });

  @override
  State<ReturnPeriodEditor> createState() => _ReturnPeriodEditorState();
}

class _ReturnPeriodEditorState extends State<ReturnPeriodEditor> {
  final _yearController = TextEditingController();
  final _flowController = TextEditingController();
  bool _isAddingPeriod = false;
  String? _validationError;

  // Common return period suggestions
  static const List<int> _commonReturnPeriods = [2, 5, 10, 25, 50, 100];

  @override
  void dispose() {
    _yearController.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sortedPeriods =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing return periods list
        if (sortedPeriods.isNotEmpty) ...[
          _buildReturnPeriodsList(sortedPeriods),
          const SizedBox(height: 16),
        ],

        // Quick add suggestions (only show periods not already added)
        _buildQuickAddSuggestions(),

        const SizedBox(height: 16),

        // Add custom return period section
        if (!_isAddingPeriod) ...[
          OutlinedButton.icon(
            onPressed: _startAddingPeriod,
            icon: const Icon(Icons.add),
            label: const Text('Add Custom Return Period'),
          ),
        ] else ...[
          _buildAddPeriodForm(),
        ],

        // Validation info
        if (widget.returnPeriods.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildValidationInfo(),
        ],
      ],
    );
  }

  Widget _buildReturnPeriodsList(List<MapEntry<int, double>> sortedPeriods) {
    return Column(
      children:
          sortedPeriods.map((entry) {
            final year = entry.key;
            final flow = entry.value;
            final isValid = _isReturnPeriodValid(year, flow);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Year badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isValid
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$year yr',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color:
                              isValid
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                  : Colors.orange.shade800,
                          fontSize: 12,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Flow value
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_formatFlow(flow)} ${widget.unit}',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          if (!isValid)
                            Text(
                              'Should be higher than shorter return periods',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Actions
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editReturnPeriod(year, flow),
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit',
                        ),
                        IconButton(
                          onPressed: () => _removeReturnPeriod(year),
                          icon: const Icon(Icons.delete, size: 18),
                          tooltip: 'Remove',
                          color: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildQuickAddSuggestions() {
    final availablePeriods =
        _commonReturnPeriods
            .where((year) => !widget.returnPeriods.containsKey(year))
            .toList();

    if (availablePeriods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Add Common Periods:',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              availablePeriods.map((year) {
                return ActionChip(
                  label: Text('$year year'),
                  onPressed: () => _quickAddReturnPeriod(year),
                  avatar: const Icon(Icons.add, size: 16),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildAddPeriodForm() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add Custom Return Period',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            if (_validationError != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _yearController,
                    decoration: const InputDecoration(
                      labelText: 'Return Period (years)',
                      hintText: 'e.g., 20',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _flowController,
                    decoration: InputDecoration(
                      labelText: 'Flow (${widget.unit})',
                      hintText: 'e.g., 15000',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                TextButton(
                  onPressed: _cancelAddingPeriod,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveReturnPeriod,
                  child: const Text('Add Period'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationInfo() {
    final isValid = _areReturnPeriodsValid();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValid ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline : Icons.warning_amber,
            color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isValid
                  ? 'Return periods are valid (flows increase with return years)'
                  : 'Warning: Return periods should increase with longer return years',
              style: TextStyle(
                color: isValid ? Colors.green.shade700 : Colors.orange.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startAddingPeriod() {
    setState(() {
      _isAddingPeriod = true;
      _validationError = null;
    });
  }

  void _cancelAddingPeriod() {
    setState(() {
      _isAddingPeriod = false;
      _yearController.clear();
      _flowController.clear();
      _validationError = null;
    });
  }

  void _saveReturnPeriod() {
    final yearText = _yearController.text.trim();
    final flowText = _flowController.text.trim();

    if (yearText.isEmpty || flowText.isEmpty) {
      setState(() {
        _validationError = 'Both year and flow are required';
      });
      return;
    }

    final year = int.tryParse(yearText);
    final flow = double.tryParse(flowText);

    if (year == null || year <= 0) {
      setState(() {
        _validationError = 'Return period must be a positive number';
      });
      return;
    }

    if (flow == null || flow <= 0) {
      setState(() {
        _validationError = 'Flow must be a positive number';
      });
      return;
    }

    if (widget.returnPeriods.containsKey(year)) {
      setState(() {
        _validationError = 'A $year-year return period already exists';
      });
      return;
    }

    widget.onReturnPeriodChanged(year, flow);
    _cancelAddingPeriod();
  }

  void _quickAddReturnPeriod(int year) {
    // Calculate a suggested flow based on existing periods
    double suggestedFlow = _calculateSuggestedFlow(year);

    showDialog<double>(
      context: context,
      builder:
          (context) => _QuickAddDialog(
            year: year,
            unit: widget.unit,
            suggestedFlow: suggestedFlow,
          ),
    ).then((flow) {
      if (flow != null) {
        widget.onReturnPeriodChanged(year, flow);
      }
    });
  }

  double _calculateSuggestedFlow(int targetYear) {
    if (widget.returnPeriods.isEmpty) {
      // Default suggestions based on common patterns
      switch (targetYear) {
        case 2:
          return 5000;
        case 5:
          return 8000;
        case 10:
          return 12000;
        case 25:
          return 15000;
        case 50:
          return 18000;
        case 100:
          return 22000;
        default:
          return targetYear * 500.0; // Rough estimation
      }
    }

    final sortedEntries =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    // Find the closest periods to interpolate/extrapolate
    final lower = sortedEntries.lastWhere(
      (entry) => entry.key < targetYear,
      orElse: () => sortedEntries.first,
    );
    final higher = sortedEntries.firstWhere(
      (entry) => entry.key > targetYear,
      orElse: () => sortedEntries.last,
    );

    if (lower.key == higher.key) {
      // All periods are the same, extrapolate
      return targetYear > lower.key
          ? lower.value * (targetYear / lower.key)
          : lower.value * (targetYear / lower.key);
    }

    // Linear interpolation/extrapolation
    final ratio = (targetYear - lower.key) / (higher.key - lower.key);
    return lower.value + ratio * (higher.value - lower.value);
  }

  void _editReturnPeriod(int year, double currentFlow) {
    showDialog<double>(
      context: context,
      builder:
          (context) => _EditReturnPeriodDialog(
            year: year,
            currentFlow: currentFlow,
            unit: widget.unit,
          ),
    ).then((newFlow) {
      if (newFlow != null) {
        widget.onReturnPeriodChanged(year, newFlow);
      }
    });
  }

  void _removeReturnPeriod(int year) {
    showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Remove Return Period'),
            content: Text('Remove the $year-year return period?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    ).then((confirmed) {
      if (confirmed == true) {
        widget.onReturnPeriodRemoved(year);
      }
    });
  }

  bool _isReturnPeriodValid(int year, double flow) {
    final sortedEntries =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      if (entry.key == year) {
        // Check previous period
        if (i > 0 && sortedEntries[i - 1].value >= flow) {
          return false;
        }
        // Check next period
        if (i < sortedEntries.length - 1 &&
            sortedEntries[i + 1].value <= flow) {
          return false;
        }
        break;
      }
    }

    return true;
  }

  bool _areReturnPeriodsValid() {
    final sortedEntries =
        widget.returnPeriods.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

    for (int i = 1; i < sortedEntries.length; i++) {
      if (sortedEntries[i].value <= sortedEntries[i - 1].value) {
        return false;
      }
    }

    return true;
  }

  String _formatFlow(double flow) {
    if (flow >= 1000000) {
      return '${(flow / 1000000).toStringAsFixed(1)}M';
    } else if (flow >= 1000) {
      return '${(flow / 1000).toStringAsFixed(1)}K';
    } else if (flow == flow.roundToDouble()) {
      return flow.toStringAsFixed(0);
    } else {
      return flow.toStringAsFixed(1);
    }
  }
}

class _QuickAddDialog extends StatefulWidget {
  final int year;
  final String unit;
  final double suggestedFlow;

  const _QuickAddDialog({
    required this.year,
    required this.unit,
    required this.suggestedFlow,
  });

  @override
  State<_QuickAddDialog> createState() => _QuickAddDialogState();
}

class _QuickAddDialogState extends State<_QuickAddDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.suggestedFlow.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add ${widget.year}-Year Return Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Enter the flow value for the ${widget.year}-year return period:',
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'Flow (${widget.unit})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            autofocus: true,
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
            final flow = double.tryParse(_controller.text);
            if (flow != null && flow > 0) {
              Navigator.of(context).pop(flow);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditReturnPeriodDialog extends StatefulWidget {
  final int year;
  final double currentFlow;
  final String unit;

  const _EditReturnPeriodDialog({
    required this.year,
    required this.currentFlow,
    required this.unit,
  });

  @override
  State<_EditReturnPeriodDialog> createState() =>
      _EditReturnPeriodDialogState();
}

class _EditReturnPeriodDialogState extends State<_EditReturnPeriodDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentFlow.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.year}-Year Return Period'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current flow: ${widget.currentFlow} ${widget.unit}'),
          const SizedBox(height: 16),
          TextFormField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: 'New Flow (${widget.unit})',
              border: const OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            autofocus: true,
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
            final flow = double.tryParse(_controller.text);
            if (flow != null && flow > 0) {
              Navigator.of(context).pop(flow);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
