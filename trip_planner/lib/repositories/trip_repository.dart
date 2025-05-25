/// TripRepository — 封裝所有 Trip/Place/Expense 的 CRUD 與 Streams
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip.dart';
import '../models/place.dart';
import '../models/expense.dart';

class TripRepository {
  final _db = FirebaseFirestore.instance;

  /// 取得單一 Trip
  Future<Trip> getTrip(String id) async {
    final doc = await _db.collection('trips').doc(id).get();
    return Trip.fromJson(doc.data()!, doc.id);
  }

  /// 監聽該用戶的所有行程
  Stream<List<Trip>> watchTrips(String uid) => _db
      .collection('trips')
      .where('members', arrayContains: uid)
      .orderBy('startDate')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Trip.fromJson(d.data(), d.id)).toList());

  Future<String> addTrip(Trip trip) async {
    final ref = await _db.collection('trips').add(trip.toJson());
    return ref.id;
  }

  Future<void> updateTrip(String id, Map<String, Object?> data) =>
      _db.collection('trips').doc(id).update(data);

  /// 監聽單一行程的景點
  Stream<List<Place>> watchPlaces(String tripId) => _db
      .collection('trips/$tripId/places')
      .orderBy('order')
      .snapshots()
      .map((snap) => snap.docs.map((d) => Place.fromJson(d.data())).toList());

  /// 批次更新景點順序
  Future<void> updatePlacesOrder(String tripId, List<Place> places) async {
    final batch = _db.batch();
    for (var i = 0; i < places.length; i++) {
      final ref = _db.doc('trips/$tripId/places/${places[i].id}');
      batch.update(ref, {'order': i});
    }
    await batch.commit();
  }

  Future<void> deletePlace(String tripId, String placeId) =>
      _db.doc('trips/$tripId/places/$placeId').delete();

  /// 新增景點，自動產生 ID 並寫回
  Future<void> addPlace(String tripId, Place p) async {
    final doc = _db.collection('trips/$tripId/places').doc();
    await doc.set({
      ...p.toJson(),
      'id': doc.id,
    });
  }

  /// 以下為費用管理
  Stream<List<Expense>> watchExpenses(String tripId) => _db
      .collection('trips/$tripId/expenses')
      .orderBy('createdAt')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Expense.fromJson(d.data(), d.id)).toList());

  Future<void> addExpense(String tripId, Expense e) =>
      _db.collection('trips/$tripId/expenses').add(e.toJson());

  Future<void> updateExpense(
          String tripId, String expId, Map<String, Object?> data) =>
      _db.doc('trips/$tripId/expenses/$expId').update(data);

  Future<void> deleteExpense(String tripId, String expId) =>
      _db.doc('trips/$tripId/expenses/$expId').delete();
}
