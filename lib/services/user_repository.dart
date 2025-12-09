import 'package:cloud_firestore/cloud_firestore.dart';

class UserRepository {
  static Future<void> salvarUsuario({
    required String uid,
    required String nome,
    required String email,
  }) async {
    await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
      'nome': nome,
      'email': email,
      'criadoEm': DateTime.now(),
    });
  }
}
