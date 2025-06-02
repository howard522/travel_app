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

  /// 監聽單一 Trip
  Stream<Trip> watchTrip(String id) => _db
      .doc('trips/$id')
      .snapshots()
      .map((d) => Trip.fromJson(d.data()!, d.id));

  /// 新增 Trip
  Future<String> addTrip(Trip trip) async {
    final ref = await _db.collection('trips').add(trip.toJson());
    return ref.id;
  }

  /// 更新 Trip 屬性
  Future<void> updateTrip(String id, Map<String, Object?> data) =>
      _db.collection('trips').doc(id).update(data);

  /* ──────────────── Invite ──────────────── */

  /// 傳送邀請：把 email 加到 invites 陣列
  Future<void> sendInvite(String tripId, String email) {
    final tripRef = _db.doc('trips/$tripId');
    return tripRef.update({
      'invites': FieldValue.arrayUnion([email])
    });
  }

  /// 接受邀請：從 invites 移除 email，並把 uid 加到 members
  Future<void> acceptInvite(
      String tripId, String uid, String email) async {
    final tripRef = _db.doc('trips/$tripId');
    await tripRef.update({
      'invites': FieldValue.arrayRemove([email]),
      'members': FieldValue.arrayUnion([uid]),
    });
  }

  /// 拒絕邀請：僅把指定 email 從 invites 陣列移除，不把該用戶加入 members
  Future<void> declineInvite(String tripId, String email) async {
    final tripRef = _db.doc('trips/$tripId');
    await tripRef.update({
      'invites': FieldValue.arrayRemove([email]),
    });
  }

  /* ──────────────── Place ──────────────── */

  /// 監聽某趟 Trip 底下所有 Place（按 order 排序）
  Stream<List<Place>> watchPlaces(String tripId) => _db
      .collection('trips/$tripId/places')
      .orderBy('order')
      .snapshots()
      .map((s) => s.docs.map((d) => Place.fromJson(d.data())).toList());

  /// 新增 Place
  Future<void> addPlace(String tripId, Place p) async {
    final doc = _db.collection('trips/$tripId/places').doc();
    await doc.set({...p.toJson(), 'id': doc.id});
  }

  /// 更新 Place
  Future<void> updatePlace(
          String tripId, String placeId, Map<String, Object?> data) =>
      _db.doc('trips/$tripId/places/$placeId').update(data);

  /// 刪除 Place
  Future<void> deletePlace(String tripId, String placeId) =>
      _db.doc('trips/$tripId/places/$placeId').delete();

  /// 重新排序 Places
  Future<void> reorderPlaces(
      String tripId, List<Place> ordered) async {
    final batch = _db.batch();
    for (var i = 0; i < ordered.length; i++) {
      final ref = _db.doc('trips/$tripId/places/${ordered[i].id}');
      batch.update(ref, {'order': i});
    }
    await batch.commit();
  }

  /* ──────────────── Expense ──────────────── */

  /// 監聽某趟 Trip 底下所有 Expense（按 createdAt 倒序）
  Stream<List<Expense>> watchExpenses(String tripId) => _db
      .collection('trips/$tripId/expenses')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => Expense.fromJson(d.data())).toList());

  /// 新增 Expense
  Future<void> addExpense(String tripId, Expense e) async {
    final doc = _db.collection('trips/$tripId/expenses').doc();
    await doc.set({...e.toJson(), 'id': doc.id});
  }

  /// 更新 Expense
  Future<void> updateExpense(
          String tripId, String expId, Map<String, Object?> data) =>
      _db.doc('trips/$tripId/expenses/$expId').update(data);

  /// 刪除 Expense
  Future<void> deleteExpense(String tripId, String expId) =>
      _db.doc('trips/$tripId/expenses/$expId').delete();

  /* ──────────────── Chat ──────────────── */

  /// 監聽某趟 Trip 底下所有 ChatMessage（按 createdAt 升冪）
  Stream<List<ChatMessage>> watchMessages(String tripId) =>
      _db
        .collection('trips/$tripId/messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) =>
          snap.docs.map((d) => ChatMessage.fromJson(d.data())).toList()
        );

  /// 傳送 ChatMessage
  Future<void> sendMessage(String tripId, ChatMessage msg) async {
    final doc = _db.collection('trips/$tripId/messages').doc();
    await doc.set({
      ...msg.toJson(),
      'id': doc.id,
    });
  }
}
