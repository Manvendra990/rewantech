import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LeadService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  // ── Leads ────────────────────────────────────────────

  Stream<QuerySnapshot> getLeads() {
    return _db
        .collection('leads')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createLead({
    required String title,
    required String clientName,
    required String description,
    required String status,
    required String createdByName,
    required String phoneNumber,
  }) async {
    await _db.collection('leads').add({
      'title': title,
      'clientName': clientName,
      'description': description,
      'status': status,
      'createdBy': currentUid,
      'createdByName': createdByName,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLeadStatus(String leadId, String status) async {
    await _db.collection('leads').doc(leadId).update({'status': status});
  }

  Future<void> deleteLead(String leadId) async {
    await _db.collection('leads').doc(leadId).delete();
  }

  // ── Comments ─────────────────────────────────────────

  Stream<QuerySnapshot> getComments(String leadId) {
    return _db
        .collection('leads')
        .doc(leadId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  Future<void> addComment({
    required String leadId,
    required String text,
    required String userName,
  }) async {
    await _db.collection('leads').doc(leadId).collection('comments').add({
      'text': text,
      'uid': currentUid,
      'userName': userName,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteComment(String leadId, String commentId) async {
    await _db
        .collection('leads')
        .doc(leadId)
        .collection('comments')
        .doc(commentId)
        .delete();
  }

  // Add this method to your existing lead_service.dart (LeadService class).
  // It saves the "won deal" details as a map field on the lead document.
  // Adjust the collection name ('leads') if yours is named differently.

  Future<void> updateWonDetails(
    String leadId,
    Map<String, dynamic> details,
  ) async {
    await FirebaseFirestore.instance.collection('leads').doc(leadId).update({
      'wonDetails': details,
    });
  }
}
