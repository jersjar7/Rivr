// lib/features/safety/presentation/pages/safety_info_page.dart
// Enhanced safety information page for notifications

import 'package:flutter/material.dart';
import 'package:rivr/core/navigation/app_router.dart';

/// Enhanced SafetyInfoPage with better UI and functionality
class SafetyInfoPage extends StatelessWidget {
  final Map<String, dynamic>? arguments;

  const SafetyInfoPage({super.key, this.arguments});

  @override
  Widget build(BuildContext context) {
    final alertLevel = arguments?['alertLevel'] ?? 'general';
    final reachId = arguments?['reachId'];
    final alertData = arguments?['alertData'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Information'),
        backgroundColor: _getAlertLevelColor(alertLevel).withValues(alpha: 0.1),
        foregroundColor: _getAlertLevelColor(alertLevel),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAlertHeader(alertLevel, reachId, alertData),
            const SizedBox(height: 24),
            _buildSafetyGuidelines(),
            const SizedBox(height: 24),
            _buildFlowSpecificGuidance(alertLevel),
            const SizedBox(height: 24),
            _buildActionButtons(context, reachId),
            const SizedBox(height: 16),
            _buildDisclaimerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertHeader(
    String alertLevel,
    String? reachId,
    Map<String, dynamic>? alertData,
  ) {
    final alertColor = _getAlertLevelColor(alertLevel);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            alertColor.withValues(alpha: 0.1),
            alertColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getAlertIcon(alertLevel), color: alertColor, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Level: ${alertLevel.toUpperCase()}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: alertColor,
                      ),
                    ),
                    if (reachId != null)
                      Text(
                        'Location: $reachId',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (alertData != null) ...[
            const SizedBox(height: 16),
            _buildAlertDetails(alertData),
          ],
        ],
      ),
    );
  }

  Widget _buildAlertDetails(Map<String, dynamic> alertData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alertData['category'] != null)
            _buildDetailRow('Flow Category', alertData['category']),
          if (alertData['flowValue'] != null)
            _buildDetailRow(
              'Current Flow',
              '${alertData['flowValue']} ${alertData['flowUnit'] ?? 'cfs'}',
            ),
          if (alertData['timestamp'] != null)
            _buildDetailRow(
              'Alert Time',
              _formatTimestamp(alertData['timestamp']),
            ),
          if (alertData['priority'] != null)
            _buildDetailRow(
              'Priority',
              alertData['priority'].toString().toUpperCase(),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyGuidelines() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Essential Safety Guidelines',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildSafetyItem(
          Icons.water,
          'Check Current Conditions',
          'Always verify real-time flow conditions before entering the water',
        ),
        _buildSafetyItem(
          Icons.notifications_off,
          'Don\'t Rely Solely on Alerts',
          'Use notifications as one source - always check multiple indicators',
        ),
        _buildSafetyItem(
          Icons.cloud,
          'Monitor Weather',
          'Be aware of changing weather and upstream conditions',
        ),
        _buildSafetyItem(
          Icons.people,
          'Inform Others',
          'Share your planned activities and expected return time',
        ),
        _buildSafetyItem(
          Icons.security,
          'Safety Equipment',
          'Carry appropriate safety gear for your activity level',
        ),
      ],
    );
  }

  Widget _buildSafetyItem(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue.shade700, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowSpecificGuidance(String alertLevel) {
    String guidance;
    Color guidanceColor;
    IconData guidanceIcon;

    switch (alertLevel.toLowerCase()) {
      case 'critical':
      case 'extreme':
        guidance =
            'DO NOT ENTER THE WATER. Extremely dangerous conditions present.';
        guidanceColor = Colors.red;
        guidanceIcon = Icons.dangerous;
        break;
      case 'high':
        guidance =
            'Exercise extreme caution. Consider postponing water activities.';
        guidanceColor = Colors.orange;
        guidanceIcon = Icons.warning;
        break;
      case 'moderate':
        guidance =
            'Use caution and ensure you have appropriate experience level.';
        guidanceColor = Colors.yellow.shade700;
        guidanceIcon = Icons.info;
        break;
      default:
        guidance =
            'Normal safety precautions apply. Enjoy your time on the water!';
        guidanceColor = Colors.green;
        guidanceIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: guidanceColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: guidanceColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(guidanceIcon, color: guidanceColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flow-Specific Guidance',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: guidanceColor,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(guidance, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, String? reachId) {
    return Column(
      children: [
        if (reachId != null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                AppRouter.navigateToForecast(
                  context,
                  reachId,
                  fromNotification: true,
                  highlightFlow: true,
                );
              },
              icon: const Icon(Icons.waves),
              label: const Text('View Current Conditions'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => AppRouter.navigateToNotificationSettings(context),
            icon: const Icon(Icons.settings),
            label: const Text('Notification Settings'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey.shade600, size: 16),
              const SizedBox(width: 8),
              Text(
                'Important Disclaimer',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This information is provided for general guidance only. '
            'Always verify current conditions from multiple sources before making safety decisions. '
            'Water conditions can change rapidly and unpredictably.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _getAlertLevelColor(String alertLevel) {
    switch (alertLevel.toLowerCase()) {
      case 'critical':
      case 'extreme':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.yellow.shade700;
      case 'low':
      case 'general':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  IconData _getAlertIcon(String alertLevel) {
    switch (alertLevel.toLowerCase()) {
      case 'critical':
      case 'extreme':
        return Icons.dangerous;
      case 'high':
        return Icons.warning;
      case 'moderate':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
