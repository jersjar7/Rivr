// lib/core/widgets/custom_text_field.dart

import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator; // Added validator parameter
  final void Function(String)? onChanged; // Added onChanged parameter

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 8.0),
      child: TextFormField(
        // Changed from TextField to TextFormField
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator, // Using the validator
        onChanged: onChanged,
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.white),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.deepPurple),
            borderRadius: BorderRadius.circular(12),
          ),
          errorBorder: OutlineInputBorder(
            // Added error border styling
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedErrorBorder: OutlineInputBorder(
            // Added focused error border
            borderSide: const BorderSide(color: Colors.red),
            borderRadius: BorderRadius.circular(12),
          ),
          hintText: hintText,
          fillColor: Colors.grey[200],
          filled: true,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}
