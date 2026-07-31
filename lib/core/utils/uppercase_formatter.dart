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
/// Uppercase letters, digits, and space only, up to 13 characters.
class VehicleNumberTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final uppercaseText = newValue.text.toUpperCase();
    final clean = uppercaseText.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      final char = clean[i];
      if (i < 2) {
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          buffer.write(char);
        }
      } else if (i < 4) {
        if (RegExp(r'[0-9]').hasMatch(char)) {
          buffer.write(char);
        }
      } else if (i < 6) {
        if (RegExp(r'[A-Z]').hasMatch(char)) {
          buffer.write(char);
        }
      } else if (i < 10) {
        if (RegExp(r'[0-9]').hasMatch(char)) {
          buffer.write(char);
        }
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Validates whether a vehicle number matches Indian registration format
/// (e.g., TG04AB1234).
bool isValidVehicleNumber(String vehicleNumber) {
  final clean = vehicleNumber.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (clean.length != 10) return false;
  return RegExp(r'^[A-Z]{2}\d{2}[A-Z]{2}\d{4}$').hasMatch(clean);
}
