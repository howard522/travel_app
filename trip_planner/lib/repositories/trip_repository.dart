// lib/repositories/trip_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/place.dart';
import '../models/expense.dart';
import '../models/chat_message.dart';

class TripRepository {
  final _db = FirebaseFirestore.instance;

  /* ──────────────── Trip ──────────────── */

  /// 取得自己是 member 的行程（以 startTime 排序）
  Stream<List<Trip>> watchTrips(String uid) => _db
      .collection('trips')
      .where('members', arrayContains: uid)
      .orderBy('startTime')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => Trip.fromJson(d.data(), d.id)).toList());

  /// 取得自己被邀請的行程（以 startTime 排序）
  Stream<List<Trip>> watchTripsByInvite(String email) => _db
      .collection('trips')
      .where('invites', arrayContains: email)
      .orderBy('startTime')
      .snapshots()
      .map((s) {
        final list =
            s.docs.map((d) => Trip.fromJson(d.data(), d.id)).toList();
        // 前端再次保證排序
        list.sort((a, b) => a.startTime.compareTo(b.startTime));
        return list;
      });

  Stream<Trip> watchTrip(String id) => _db
      .doc('trips/$id')
      .snapshots()
      .map((d) => Trip.fromJson(d.data()!, d.id));

  Future<String> addTrip(Trip trip) async {
    final ref = await _db.collection('trips').add(trip.toJson());
    return ref.id;
  }

  Future<void> updateTrip(String id, Map<String, Object?> data) =>
      _db.collection('trips').doc(id).update(data);

  /* ──────────────── Invite ──────────────── */

  Future<void> sendInvite(String tripId, String email) {
    final tripRef = _db.doc('trips/$tripId');
    return tripRef.update({
      'invites': FieldValue.arrayUnion([email])
    });
  }

  Future<void> acceptInvite(
      String tripId, String uid, String email) async {
    final tripRef = _db.doc('trips/$tripId');
    await tripRef.update({
      'invites': FieldValue.arrayRemove([email]),
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  /* ──────────────── Place ──────────────── */

  Stream<List<Place>> watchPlaces(String tripId) => _db
      .collection('trips/$tripId/places')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Place.fromJson(d.data())).toList());

  Future<void> addPlace(String tripId, Place p) async {
    final doc = _db.collection('trips/$tripId/places').doc();
    await doc.set({...p.toJson(), 'id': doc.id});
  }

  Future<void> updatePlace(
          String tripId, String placeId, Map<String, Object?> data) =>
      _db.doc('trips/$tripId/places/$placeId').update(data);

  Future<void> deletePlace(String tripId, String placeId) =>
      _db.doc('trips/$tripId/places/$placeId').delete();

  Future<void> reorderPlaces(
      String tripId, List<Place> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      final ref =
          _db.doc('trips/$tripId/places/${ordered[i].id}');
      batch.update(ref, {'order': i});
    }
    await batch.commit();
  }

  /* ──────────────── Expense ──────────────── */

  Stream<List<Expense>> watchExpenses(String tripId) => _db
      .collection('trips/$tripId/expenses')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Expense.fromJson(d.data())).toList());

  Future<void> addExpense(String tripId, Expense e) async {
    final doc = _db.collection('trips/$tripId/expenses').doc();
    await doc.set({...e.toJson(), 'id': doc.id});
  }

  Future<void> updateExpense(
          String tripId, String expId, Map<String, Object?> data) =>
      _db.doc('trips/$tripId/expenses/$expId').update(data);

  Future<void> deleteExpense(String tripId, String expId) =>
      _db.doc('trips/$tripId/expenses/$expId').delete();

  /* ──────────────── Chat ──────────────── */

  Stream<List<ChatMessage>> watchMessages(String tripId) =>
      _db
        .collection('trips/$tripId/messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
          snap.docs.map((d) => ChatMessage.fromJson(d.data())).toList()
        );

  Future<void> sendMessage(String tripId, ChatMessage msg) async {
    final doc = _db.collection('trips/$tripId/messages').doc();
    await doc.set({
      ...msg.toJson(),
      'id': doc.id,
    });
  }
}
