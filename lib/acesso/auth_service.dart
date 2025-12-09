import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class AuthService {
  // Instâncias do Firebase
  final FirebaseAuth _auth;
  final FirebaseAnalytics _analytics;
  final FirebaseFirestore _firestore;
  final DatabaseReference _database;
  String? _token;

  // Singleton (opcional)
  static AuthService? _instance;
  
  factory AuthService() {
    _instance ??= AuthService._internal(
      FirebaseAuth.instance,
      FirebaseAnalytics.instance,
      FirebaseFirestore.instance,
      FirebaseDatabase.instance.ref(),
    );
    return _instance!;
  }
  
  AuthService._internal(
    this._auth,
    this._analytics,
    this._firestore,
    this._database,
  );

  // Getter para o token
  String? get token => _token;

  // ==================== INICIALIZAÇÃO ====================
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');
      
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        print('Usuário Firebase já logado: ${firebaseUser.email}');
        _token = 'firebase_${firebaseUser.uid}';
        await prefs.setString('token', _token!);
      }
      
      print('AuthService inicializado');
    } catch (e) {
      print('Erro na inicialização do AuthService: $e');
    }
  }

  // ==================== RECUPERAR SENHA ====================
  Future<Map<String, dynamic>> esqueciSenha(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());

      return {
        'success': true,
        'message': 'Enviamos um email com instruções para redefinição de senha.'
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getFirebaseErrorMessage(e),
        'errorCode': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro inesperado ao tentar recuperar senha.',
        'error': e.toString(),
      };
    }
  }

  // ==================== CADASTRO ====================
  Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String email,
    required String senha,
  }) async {
    try {
      print('🔄 Iniciando cadastro para: $nome - $email');

      // 1. Criar usuário no Firebase Auth
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: senha.trim(),
      );
      
      final User user = userCredential.user!;
      print('✅ Usuário criado no Firebase Auth: ${user.uid}');

      // 2. Atualizar displayName
      await user.updateDisplayName(nome);
      await user.reload();

      // 3. Enviar email de verificação
      await user.sendEmailVerification();

      // 4. Salvar Firestore
      await _firestore.collection("usuarios").doc(user.uid).set({
        "nome": nome.trim(),
        "email": email.trim(),
        "uid": user.uid,
        "emailVerificado": false,
        "criadoEm": FieldValue.serverTimestamp(),
        "atualizadoEm": FieldValue.serverTimestamp(),
      });

      // 5. Criar casa automática
      await _criarCasaAutomatica(user.uid, nome, email);

      // 6. Registrar evento Analytics
      await _analytics.logEvent(
        name: 'user_registered',
        parameters: {
          'user_id': user.uid,
          'user_email': email,
          'platform': _getPlatform(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // 7. Salvar dados localmente
      final userData = {
        'nome': nome,
        'email': email,
        'id': user.uid,
        'emailVerified': false,
      };

      final token = 'firebase_${user.uid}';
      await _saveToken(token);
      await _saveUserData(userData);

      return {
        'success': true,
        'message': '✅ Cadastro realizado com sucesso!\n'
                   '📧 Enviamos um email de verificação para $email.',
        'user': userData,
        'requiresEmailVerification': true,
        'userId': user.uid,
      };

    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getFirebaseErrorMessage(e),
        'errorCode': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro inesperado. Tente novamente.',
        'error': e.toString(),
      };
    }
  }

  // ==================== CRIAR CASA AUTOMÁTICA ====================
  Future<void> _criarCasaAutomatica(String userId, String nome, String email) async {
    try {
      final userName = nome.split(' ').first;
      
      final houseData = {
        'owner_id': userId,
        'owner_email': email,
        'owner_name': nome,
        'house_name': 'Casa de $userName',
        'created_at': ServerValue.timestamp,
        'members': {
          userId: {
            'email': email,
            'name': nome,
            'role': 'owner',
            'joined_at': ServerValue.timestamp,
          }
        },
        'settings': {
          'theme': 'light',
          'notifications': true,
          'language': 'pt-BR',
        },
        'rooms': {
          'sala_principal': {
            'name': 'Sala Principal',
            'type': 'living_room',
            'created_at': ServerValue.timestamp,
          }
        }
      };
      
      final houseRef = _database.child('houses').push();
      final houseId = houseRef.key!;
      
      await houseRef.set(houseData);

      await _database.child('users').child(userId).set({
        'email': email,
        'name': nome,
        'house_id': houseId,
        'created_at': ServerValue.timestamp,
      });

    } catch (e) {
      print('⚠️ Erro ao criar casa automática: $e');
    }
  }

  // ==================== LOGIN ====================
  Future<Map<String, dynamic>> login({
    required String email,
    required String senha,
  }) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: senha.trim(),
      );
      
      final User user = userCredential.user!;

      if (!user.emailVerified) {
        return {
          'success': false,
          'message': '📧 Por favor, verifique seu email antes de entrar.',
          'requiresEmailVerification': true,
          'user': {
            'nome': user.displayName ?? email.split('@')[0],
            'email': email,
            'id': user.uid,
            'emailVerified': false,
          }
        };
      }

      final userData = {
        'nome': user.displayName ?? email.split('@')[0],
        'email': email,
        'id': user.uid,
        'emailVerified': user.emailVerified,
      };

      final token = 'firebase_${user.uid}';
      await _saveToken(token);
      await _saveUserData(userData);

      return {
        'success': true,
        'user': userData,
        'message': 'Login realizado com sucesso!',
      };

    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _getFirebaseErrorMessage(e),
        'errorCode': e.code,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Erro inesperado no login',
        'error': e.toString(),
      };
    }
  }

  // ==================== MÉTODOS AUXILIARES ====================
  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userData', json.encode(userData));
  }

  String _getPlatform() {
    if (kIsWeb) return 'web';
    return Platform.operatingSystem;
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use': return 'Este email já está cadastrado.';
      case 'invalid-email': return 'O formato do email é inválido.';
      case 'user-not-found': return 'Usuário não encontrado.';
      case 'wrong-password': return 'Senha incorreta.';
      case 'weak-password': return 'A senha deve ter pelo menos 6 caracteres.';
      case 'too-many-requests': return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed': return 'Erro de conexão. Verifique sua internet.';
      default: return 'Erro: ${e.message ?? e.code}';
    }
  }

  // ==================== MÉTODOS PÚBLICOS ====================
  Future<void> logout() async {
    await _auth.signOut();
    _token = null;

    final prefs = await SharedPreferences.getInstance();
    prefs.remove('token');
    prefs.remove('userData');
  }

  Future<bool> isAuthenticated() async {
    return _auth.currentUser != null;
  }

  User? get currentUser => _auth.currentUser;
}