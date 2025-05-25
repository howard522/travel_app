/// TripRepository — 封裝所有 Trip/Place/Expense 的 CRUD 與 Stream
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/place.dart';
import '../models/expense.dart';

class TripRepository {
  final _db = FirebaseFirestore.instance;

  /// ------------- Trip -------------
  Stream<List<Trip>> watchTrips(String uid) => _db
      .collection('trips')
      .where('members', arrayContains: uid)
      .orderBy('startDate')
      .snapshots()
      .map((s) => s.docs.map((d) => Trip.fromJson(d.data(), d.id)).toList());

  Future<String> addTrip(Trip trip) async {
    final ref = await _db.collection('trips').add(trip.toJson());
    return ref.id;
  }

  Future<void> updateTrip(String id, Map<String, Object?> data) =>
      _db.collection('trips').doc(id).update(data);

  /// ------------- Place -------------
  Stream<List<Place>> watchPlaces(String tripId) {
    return _db
        .collection('trips/$tripId/places')
        .orderBy('order')
        .snapshots()
        .map((s) => s.docs.map((d) => Place.fromJson(d.data())).toList());
  }

  Future<void> updatePlace(
    String tripId,
    String placeId,
    Map<String, Object?> data,
  ) => _db.doc('trips/$tripId/places/$placeId').update(data);

  Future<void> deletePlace(String tripId, String placeId) =>
      _db.doc('trips/$tripId/places/$placeId').delete();

  /// ------------- Expense -------------
  Stream<List<Expense>> watchExpenses(String tripId) => _db
      .collection('trips/$tripId/expenses')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map((d) => Expense.fromJson(d.data(), d.id)).toList());

  Future<void> addExpense(String tripId, Expense e) =>
      _db.collection('trips/$tripId/expenses').add(e.toJson());

  Future<void> updateExpense(
    String tripId,
    String expId,
    Map<String, Object?> data,
  ) => _db.doc('trips/$tripId/expenses/$expId').update(data);

  Future<void> deleteExpense(String tripId, String expId) =>
      _db.doc('trips/$tripId/expenses/$expId').delete();
    Future<void> reorderPlaces(String tripId, List<Place> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      final ref = _db.doc('trips/$tripId/places/${ordered[i].id}');
      batch.update(ref, {'order': i});
    }
    await batch.commit();
  }

  Future<void> addPlace(String tripId, Place p) async {
    final doc = _db.collection('trips/$tripId/places').doc(); // 自動產 ID
    await doc.set({
      ...p.toJson(),
      'id': doc.id, // 寫回自動產生的 id
    });
  }
  
}
