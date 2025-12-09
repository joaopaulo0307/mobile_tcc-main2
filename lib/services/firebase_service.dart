import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Eventos
  Future<List<Event>> getEvents(String houseId) async {
    try {
      final snapshot = await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('events')
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => Event.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('Erro ao buscar eventos: $e');
      return [];
    }
  }

  Future<void> addEvent(String houseId, Event event) async {
    try {
      await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('events')
          .doc(event.id)
          .set(event.toMap());
    } catch (e) {
      print('Erro ao adicionar evento: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(String houseId, Event event) async {
    try {
      await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('events')
          .doc(event.id)
          .update(event.toMap());
    } catch (e) {
      print('Erro ao atualizar evento: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String houseId, String eventId) async {
    try {
      await _firestore
          .collection('houses')
          .doc(houseId)
          .collection('events')
          .doc(eventId)
          .delete();
    } catch (e) {
      print('Erro ao deletar evento: $e');
      rethrow;
    }
  }

  // Usuário
  Future<String?> getCurrentHouseId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['house_id'];
    } catch (e) {
      print('Erro ao buscar house_id: $e');
      return null;
    }
  }
}