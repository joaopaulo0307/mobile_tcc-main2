import 'package:flutter/material.dart';
// REMOVIDO: import do provider

class AppProvider {
  // REMOVIDO: providers list
  
  // Métodos auxiliares podem ser mantidos se úteis
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }
}