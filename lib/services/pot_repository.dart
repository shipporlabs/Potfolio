import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';

abstract class PotRepository {
  Future<List<Pot>> list(String uid);
  Future<Pot> save(String uid, Pot pot);
  Future<void> delete(String uid, String id);
  Future<void> saveProfile(String uid, Map<String, dynamic> data);
}

/// Cloud Firestore (free Spark plan): users/{uid} and users/{uid}/pots/{potId}.
class FirestorePotRepository implements PotRepository {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _pots(String uid) => _db.collection('users').doc(uid).collection('pots');

  @override
  Future<List<Pot>> list(String uid) async {
    final q = await _pots(uid).orderBy('createdAt', descending: true).get();
    return q.docs.map((d) => Pot.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<Pot> save(String uid, Pot pot) async {
    final ref = pot.id.isEmpty ? _pots(uid).doc() : _pots(uid).doc(pot.id);
    await ref.set(pot.toJson());
    return Pot.fromJson(ref.id, pot.toJson());
  }

  @override
  Future<void> delete(String uid, String id) => _pots(uid).doc(id).delete();

  @override
  Future<void> saveProfile(String uid, Map<String, dynamic> data) =>
      _db.collection('users').doc(uid).set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
}

/// Demo mode: pots saved on the device.
class LocalPotRepository implements PotRepository {
  String _k(String uid) => 'potfolio_pots_$uid';

  @override
  Future<List<Pot>> list(String uid) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k(uid));
    if (raw == null) return [];
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final pots = m.entries.map((e) => Pot.fromJson(e.key, Map<String, dynamic>.from(e.value as Map))).toList();
    pots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return pots;
  }

  @override
  Future<Pot> save(String uid, Pot pot) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k(uid));
    final m = raw == null ? <String, dynamic>{} : jsonDecode(raw) as Map<String, dynamic>;
    final id = pot.id.isEmpty ? const Uuid().v4() : pot.id;
    m[id] = pot.toJson();
    await p.setString(_k(uid), jsonEncode(m));
    return Pot.fromJson(id, pot.toJson());
  }

  @override
  Future<void> delete(String uid, String id) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k(uid));
    if (raw == null) return;
    final m = jsonDecode(raw) as Map<String, dynamic>..remove(id);
    await p.setString(_k(uid), jsonEncode(m));
  }

  @override
  Future<void> saveProfile(String uid, Map<String, dynamic> data) async {}
}
