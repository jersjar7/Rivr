// lib/core/widgets/live_validation_field.dart

import 'package:flutter/material.dart';
import 'dart:async';

class LiveValidationField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final Duration debounceTime;
  final FocusNode? focusNode;
  final bool validateOnChange;

  const LiveValidationField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.debounceTime = const Duration(milliseconds: 500),
    this.focusNode,
    this.validateOnChange = true,
  });

  @override
  State<LiveValidationField> createState() => _LiveValidationFieldState();
}

class _LiveValidationFieldState extends State<LiveValidationField> {
  String? _errorText;
  bool _isDirty = false;
  Timer? _debounce;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);

    // Initialize with current value
    if (widget.controller.text.isNotEmpty) {
      _validate(widget.controller.text);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;

    // When focus is lost, validate regardless of debounce
    if (_isFocused && !hasFocus && _isDirty) {
      _debounce?.cancel();
      _validate(widget.controller.text);
    }

    setState(() {
      _isFocused = hasFocus;
    });
  }

  void _onTextChanged(String value) {
    if (widget.onChanged != null) {
      widget.onChanged!(value);
    }

    // Skip validation if not dirty yet or if validateOnChange is false
    if (!widget.validateOnChange && !_isDirty) return;

    setState(() {
      _isDirty = true;
    });

    // Cancel previous debounce timer
    _debounce?.cancel();

    // Set up new debounce timer
    _debounce = Timer(widget.debounceTime, () {
      _validate(value);
    });
  }

  void _validate(String value) {
    if (widget.validator == null) return;

    final error = widget.validator!(value);

    setState(() {
      _errorText = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            focusNode: _focusNode,
            onChanged: _onTextChanged,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color:
                      _errorText != null ? Colors.red.shade300 : Colors.white,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _errorText != null ? Colors.red : Colors.deepPurple,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              hintText: widget.hintText,
              fillColor: Colors.grey[200],
              filled: true,
              prefixIcon:
                  widget.prefixIcon != null ? Icon(widget.prefixIcon) : null,
              suffixIcon: widget.suffixIcon,
              errorText: _isDirty ? _errorText : null,
            ),
            validator: widget.validator,
          ),

          // Recovery suggestion for errors
          if (_isDirty && _errorText != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Text(
                _getRecoverySuggestion(_errorText!),
                style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // Helper method to provide contextual recovery tips
  String _getRecoverySuggestion(String error) {
    if (error.toLowerCase().contains('password')) {
      return 'Tip: Use a mix of uppercase, lowercase, numbers, and special characters';
    } else if (error.toLowerCase().contains('email')) {
      return 'Format should be: example@domain.com';
    } else {
      return 'Please fix this field before submitting';
    }
  }
}
