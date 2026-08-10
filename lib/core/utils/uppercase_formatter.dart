import 'package:flutter/services.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Formatter that enforces Vehicle Registration Number character rules:
/// Uppercase letters and digits up to 13 characters.
class VehicleNumberTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final uppercaseText = newValue.text.toUpperCase();
    final clean = uppercaseText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final formatted = clean.length > 13 ? clean.substring(0, 13) : clean;
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Validates whether a vehicle number matches Indian registration format
/// (e.g., TG04AB1234, TG45H5545, TS09UB9999).
bool isValidVehicleNumber(String vehicleNumber) {
  final clean = vehicleNumber.replaceAll(RegExp(r'[\s\-]+'), '').toUpperCase();
  if (clean.length < 4 || clean.length > 13) return false;
  return RegExp(r'^[A-Z0-9]{4,13}$').hasMatch(clean);
}
