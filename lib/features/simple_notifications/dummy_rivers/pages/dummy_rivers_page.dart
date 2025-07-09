import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dummy_rivers_provider.dart';
import '../widgets/dummy_river_card.dart';
import 'create_dummy_river_page.dart';

class DummyRiversPage extends StatefulWidget {
  const DummyRiversPage({super.key});

  @override
  State<DummyRiversPage> createState() => _DummyRiversPageState();
}

class _DummyRiversPageState extends State<DummyRiversPage> {
  @override
  void initState() {
    super.initState();
    // Load dummy rivers when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DummyRiversProvider>().loadDummyRivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dummy Rivers'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'create_scenarios',
                    child: Row(
                      children: [
                        Icon(Icons.science),
                        SizedBox(width: 8),
                        Text('Create Test Scenarios'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete All Rivers'),
                      ],
                    ),
                  ),
                ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Consumer<DummyRiversProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading dummy rivers...'),
                ],
              ),
            );
          }

          if (provider.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading dummy rivers',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadDummyRivers(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () => provider.clearError(),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.rivers.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildRiversList(provider);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateRiver,
        icon: const Icon(Icons.add),
        label: const Text('New River'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water, size: 80, color: Colors.blue.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'No dummy rivers yet',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Create dummy rivers to test your flow notifications',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            Column(
              children: [
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _createTestScenarios,
                  icon: const Icon(Icons.science),
                  label: const Text('Create Test Scenarios'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiversList(DummyRiversProvider provider) {
    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${provider.riversCount} dummy river${provider.riversCount == 1 ? '' : 's'} for testing',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => provider.loadDummyRivers(),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        // Rivers list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.rivers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final river = provider.rivers[index];
              return DummyRiverCard(
                river: river,
                onTap: () => _selectRiver(river),
                onEdit: () => _editRiver(river),
                onDelete: () => _deleteRiver(river),
                onDuplicate: () => _duplicateRiver(river),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'create_scenarios':
        _createTestScenarios();
        break;
      case 'delete_all':
        _deleteAllRivers();
        break;
    }
  }

  Future<void> _createTestScenarios() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Test Scenarios'),
            content: const Text(
              'This will create 4 predefined test rivers with different characteristics:\n\n'
              '• Low Flow Test River (easy alerts)\n'
              '• High Flow Test River (harder alerts)\n'
              '• Metric Test River (cms units)\n'
              '• Edge Case Test River (close values)\n\n'
              'Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final provider = context.read<DummyRiversProvider>();
      final success = await provider.createTestScenarios();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Test scenarios created successfully'
                  : 'Failed to create test scenarios',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAllRivers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete All Rivers'),
            content: const Text(
              'Are you sure you want to delete all dummy rivers? '
              'This action cannot be undone.',
            ),
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
                child: const Text('Delete All'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final provider = context.read<DummyRiversProvider>();
      final success = await provider.deleteAllDummyRivers();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'All dummy rivers deleted' : 'Failed to delete rivers',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToCreateRiver() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateDummyRiverPage()),
    );
  }

  void _selectRiver(river) {
    final provider = context.read<DummyRiversProvider>();
    provider.selectRiver(river);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${river.name}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _editRiver(river) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateDummyRiverPage(existingRiver: river),
      ),
    );
  }

  Future<void> _deleteRiver(river) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete River'),
            content: Text('Are you sure you want to delete "${river.name}"?'),
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
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final provider = context.read<DummyRiversProvider>();
      final success = await provider.deleteDummyRiver(river.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'River deleted successfully' : 'Failed to delete river',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _duplicateRiver(river) async {
    final provider = context.read<DummyRiversProvider>();

    // Create a copy with a new name
    final duplicatedRiver = river.copyWith(
      id: '', // Will be set by service
      name: '${river.name} (Copy)',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final success = await provider.createDummyRiver(duplicatedRiver);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success != null
                ? 'River duplicated successfully'
                : 'Failed to duplicate river',
          ),
          backgroundColor: success != null ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
