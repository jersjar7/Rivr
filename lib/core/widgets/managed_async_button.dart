// lib/core/widgets/managed_async_button.dart

import 'package:flutter/material.dart';

/// A button that handles async operations with loading states
class ManagedAsyncButton extends StatefulWidget {
  final String text;
  final String loadingText;
  final Future<void> Function() onPressed;
  final Color color;
  final Color textColor;
  final bool isLoading;
  final Widget? icon;
  final double width;
  final double height;
  final bool isEnabled;

  const ManagedAsyncButton({
    super.key,
    required this.text,
    this.loadingText = 'Please wait...',
    required this.onPressed,
    this.color = const Color(0xFF2B5876),
    this.textColor = Colors.white,
    this.isLoading = false,
    this.icon,
    this.width = double.infinity,
    this.height = 50,
    this.isEnabled = true,
  });

  @override
  State<ManagedAsyncButton> createState() => _ManagedAsyncButtonState();
}

class _ManagedAsyncButtonState extends State<ManagedAsyncButton> {
  bool _isLocalLoading = false;

  // Combined loading state (either local or passed from parent)
  bool get isLoading => _isLocalLoading || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ElevatedButton(
          onPressed: isLoading || !widget.isEnabled ? null : _handlePress,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.color,
            foregroundColor: widget.textColor,
            disabledBackgroundColor: Colors.grey.shade400,
            disabledForegroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: _buildButtonContent(),
        ),
      ),
    );
  }

  Widget _buildButtonContent() {
    if (isLoading) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: widget.textColor,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.loadingText,
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          widget.icon!,
          const SizedBox(width: 12),
          Text(
            widget.text,
            style: TextStyle(
              color: widget.textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.text,
      style: TextStyle(
        color: widget.textColor,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Future<void> _handlePress() async {
    // Prevent double-press
    if (isLoading) return;

    // Set local loading state
    setState(() {
      _isLocalLoading = true;
    });

    try {
      // Execute the async action
      await widget.onPressed();
    } finally {
      // If component is still mounted, reset loading state
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
      }
    }
  }
}
