// lib/features/settings/presentation/pages/biometric_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rivr/features/auth/presentation/providers/auth_provider.dart';
import 'package:rivr/core/theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Biometric Authentication')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Biometric Authentication Settings',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (!_isBiometricAvailable) ...[
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Biometric authentication is not available on this device',
                                style: TextStyle(fontSize: 16),
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
                        ),
                        value: _isBiometricEnabled,
                        onChanged: (value) => _toggleBiometric(),
                        activeColor: AppColors.primaryColor,
                      ),

                      const SizedBox(height: 20),

                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'How it works',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Biometric login allows you to sign in to the app using your fingerprint or face instead of entering your password each time.',
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Your biometric data never leaves your device and is protected by your device\'s security systems.',
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
