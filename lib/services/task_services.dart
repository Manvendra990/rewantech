import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:rtstrack/widgets/alarm_helper.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // final FirebaseStorage _storage = FirebaseStorage.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Stream<List<Map<String, dynamic>>> getTeammates() {
    return _firestore.collection('registration').snapshots().map((snap) {
      return snap.docs
          .map(
            (doc) => {
              'uid': doc.id,
              'name': (doc.data()['name'] ?? '') as String,
              'role': (doc.data()['role'] ?? '') as String,
            },
          )
          .toList();
    });
  }

  Future<Map<String, dynamic>> getMyAttendanceSummary() async {
    final uid = currentUid;
    if (uid == null) return {'present': 0, 'total': 0};

    try {
      final snap = await _firestore.collection('attendance').get();
      int total = 0;
      int present = 0;

      for (final dateDoc in snap.docs) {
        final memberDoc = await _firestore
            .collection('attendance')
            .doc(dateDoc.id)
            .collection('members')
            .doc(uid)
            .get();

        if (memberDoc.exists) {
          total++;
          final status = memberDoc.data()?['status'] ?? '';
          if (status == 'present') present++;
        }
      }

      return {'present': present, 'total': total};
    } catch (e) {
      return {'present': 0, 'total': 0};
    }
  }

  // ✅ Content type helper
  String _getContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'docx':
        return 'application/msword';
      default:
        return 'application/octet-stream';
    }
  }

  Future<String?> createTask({
    required String projectId,
    required String projectName,
    required String title,
    required String description,
    String? reminderDate,
    String? reminderTime,
    required String priority,
    required List<Map<String, String>> assignees,
    DateTime? reminderDateTime,
    PlatformFile? attachmentFile,
  }) async {
    try {
      // ✅ Firebase Storage mein upload karo
      String attachmentUrl = '';
      String attachmentName = '';

      // ✅ Resolve the creator's display name once, so the task doc carries
      // both the uid (for permission checks / arrayContains queries) and a
      // human-readable name (so UI like the dashboard's "Created by" block
      // doesn't need a separate lookup per task).
      String assignedByName = '';
      if (currentUid != null) {
        final creatorDoc = await _firestore
            .collection('registration')
            .doc(currentUid)
            .get();
        assignedByName = (creatorDoc.data()?['name'] ?? '').toString();
      }

      final projectRef = _firestore.collection('projects').doc(projectId);
      final taskRef = projectRef.collection('tasks').doc(); // pre-generate ID

      await _firestore.runTransaction((transaction) async {
        final projectSnap = await transaction.get(projectRef);
        final projectData = projectSnap.data();
        final currentStatus = projectData?['status'];

        // ✅ Sirf 'new' status ko 'active' me badlo — kisi aur status ko touch mat karo
        if (currentStatus == 'new') {
          transaction.update(projectRef, {'status': 'active'});
        }

        transaction.set(taskRef, {
          'title': title.trim(),
          'description': description.trim(),
          'reminderDate': reminderDate,
          'reminderTime': reminderTime,
          'priority': priority,
          'assignedToUids': assignees.map((a) => a['uid']).toList(),
          'assignedToNames': assignees.map((a) => a['name']).toList(),
          'assignedByUid': currentUid,
          'assignedByName': assignedByName,
          'status': 'pending',
          'projectName': projectName,
          'attachmentName': attachmentName, // ✅ file name
          'attachmentUrl': attachmentUrl, // ✅ download URL
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (reminderDateTime != null) {
        await AlarmHelper.scheduleTaskAlarm(
          taskId: taskRef.id,
          title: title.trim(),
          dateTime: reminderDateTime,
        );
      }

      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<QuerySnapshot> getAllMyTasks() {
    return _firestore
        .collectionGroup('tasks')
        .where('assignedToUids', arrayContains: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getMyTasks(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .where('assignedToUids', arrayContains: currentUid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markTaskComplete(
    String projectId,
    String taskId,
    String completedByName,
  ) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .update({
          'status': 'completed',
          'completedBy': completedByName,
          'completedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<String?> updateTask({
    required String projectId,
    required String taskId,
    required String title,
    required String description,
    String? reminderDate,
    String? reminderTime,
    required String priority,
    required List<Map<String, String>> assignees,
  }) async {
    try {
      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'title': title.trim(),
            'description': description.trim(),
            'reminderDate': reminderDate,
            'reminderTime': reminderTime,
            'priority': priority,
            'assignedToUids': assignees.map((a) => a['uid']).toList(),
            'assignedToNames': assignees.map((a) => a['name']).toList(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> deleteTask(String projectId, String taskId) async {
    await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('tasks')
        .doc(taskId)
        .delete();
  }
}