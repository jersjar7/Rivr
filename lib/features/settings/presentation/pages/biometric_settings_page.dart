// lib/features/settings/presentation/pages/biometric_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';

class BiometricSettingsPage extends StatefulWidget {
  const BiometricSettingsPage({super.key});

  @override
  State<BiometricSettingsPage> createState() => _BiometricSettingsPageState();
}

class _BiometricSettingsPageState extends State<BiometricSettingsPage> {
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isAvailable = await authProvider.isBiometricAvailable;
    final isEnabled = await authProvider.isBiometricEnabled;
    setState(() {
      _isBiometricAvailable = isAvailable;
      _isBiometricEnabled = isEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleBiometric() async {
    setState(() {
      _isLoading = true;
    });
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (_isBiometricEnabled) {
      await authProvider.disableBiometric();
    } else {
      await authProvider.enableBiometric();
    }
    await _checkBiometricStatus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Biometric Authentication', style: textTheme.titleMedium),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                ),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Biometric Authentication Settings',
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),

                    if (!_isBiometricAvailable) ...[
                      Card(
                        color: colors.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(Icons.error_outline, color: colors.error),
                              const SizedBox(height: 8),
                              Text(
                                'Biometric authentication is not available on this device',
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      SwitchListTile(
                        title: const Text('Enable Biometric Login'),
                        subtitle: Text(
                          _isBiometricEnabled
                              ? 'You can use your fingerprint or face to log in'
                              : 'Enable to log in with your fingerprint or face',
                          style: textTheme.bodyMedium,
                        ),
                        value: _isBiometricEnabled,
                        onChanged: (value) => _toggleBiometric(),
                        activeColor: colors.primary,
                      ),

                      const SizedBox(height: 20),

                      Card(
                        color: colors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How it works',
                                style: textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Biometric login allows you to sign in to the app using your fingerprint or face instead of entering your password each time.',
                                style: textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Your biometric data never leaves your device and is protected by your device\'s security systems.',
                                style: textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
