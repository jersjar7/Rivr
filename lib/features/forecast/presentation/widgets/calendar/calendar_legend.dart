// lib/features/forecast/presentation/widgets/calendar/calendar_legend.dart

import 'package:flutter/material.dart';
import 'package:rivr/features/forecast/utils/flow_thresholds.dart';

class CalendarLegend extends StatelessWidget {
  final bool compact;
  final EdgeInsets padding;

  const CalendarLegend({
    super.key,
    this.compact = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
  });

  @override
  Widget build(BuildContext context) {
    // Get categories and descriptions from FlowThresholds
    final categories = FlowThresholds.categories.keys.toList();
    final descriptions = FlowThresholds.categories.values.toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Flow Legend',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (compact)
              _buildCompactLegend(categories)
            else
              _buildDetailedLegend(categories, descriptions),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactLegend(List<String> categories) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:
          categories.map((category) {
            final color = FlowThresholds.getColorForCategory(category);
            return Tooltip(
              message: FlowThresholds.categories[category] ?? '',
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: Colors.grey.shade400,
                          width: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(category, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildDetailedLegend(
    List<String> categories,
    List<String> descriptions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(categories.length, (index) {
        final category = categories[index];
        final description = descriptions[index];
        final color = FlowThresholds.getColorForCategory(category);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 8, top: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 1,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(description, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class CollapsibleLegend extends StatefulWidget {
  final bool initiallyExpanded;
  final EdgeInsets padding;

  const CollapsibleLegend({
    super.key,
    this.initiallyExpanded = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
  });

  @override
  State<CollapsibleLegend> createState() => _CollapsibleLegendState();
}

class _CollapsibleLegendState extends State<CollapsibleLegend> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Flow Legend',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade700,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                bottom: 16.0,
              ),
              child: CalendarLegend(compact: false, padding: EdgeInsets.zero),
            ),
            crossFadeState:
                _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}
