import 'package:flutter/material.dart';

// Interface/contrato para facilitar o mock
abstract class BaseThemeService extends ChangeNotifier {
  bool get isDarkMode;
  Color get backgroundColor;
  Color get cardColor;
  Color get textColor;
  Color get primaryColor;
  Color get secondaryColor;
  ThemeData get themeData;
  
  void toggleTheme();
  void setDarkMode(bool value);
}

class ThemeService extends BaseThemeService {
  // Singleton - mas com opção de override para testes
  static ThemeService? _instance;
  
  // Construtor factory com flag para testes
  factory ThemeService({bool useSingleton = true}) {
    if (useSingleton && _instance != null) {
      return _instance!;
    }
    final instance = ThemeService._internal();
    if (useSingleton) {
      _instance = instance;
    }
    return instance;
  }
  
  ThemeService._internal();

  // Cores - agora como getters de instância
  @override
  Color get primaryColor => const Color(0xFF133A67);
  
  @override
  Color get secondaryColor => const Color(0xFF4CAF50);

  // Estado
  bool _isDarkMode = false;
  
  @override
  bool get isDarkMode => _isDarkMode;

  // Métodos
  @override
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  @override
  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }

  // ThemeData
  @override
  ThemeData get themeData {
    if (_isDarkMode) {
      return ThemeData.dark().copyWith(
        primaryColor: primaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF133A67),
          foregroundColor: Colors.white,
        ),
      );
    } else {
      return ThemeData.light().copyWith(
        primaryColor: primaryColor,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF133A67),
          foregroundColor: Colors.white,
        ),
      );
    }
  }

  // Getters básicos para compatibilidade
  @override
  Color get backgroundColor => _isDarkMode ? Colors.black : Colors.white;
  
  @override
  Color get cardColor => _isDarkMode ? Colors.grey[900]! : Colors.white;
  
  @override
  Color get textColor => _isDarkMode ? Colors.white : Colors.black;
}

// Classe auxiliar para injeção de dependência
class ThemeServiceProvider {
  static BaseThemeService? _testInstance;
  
  static BaseThemeService get instance {
    return _testInstance ?? ThemeService();
  }
  
  // Método para injetar mock em testes
  static void setTestInstance(BaseThemeService mock) {
    _testInstance = mock;
  }
  
  // Método para resetar após testes
  static void reset() {
    _testInstance = null;
  }
}