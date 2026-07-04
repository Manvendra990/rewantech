import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeadNotificationService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String? get currentUid => _auth.currentUser?.uid;

  Future<void> markAllRead() async {
    print('=== markAllRead CALLED ===');
    print(StackTrace.current); // ✅ yeh batayega kahan se call ho raha hai
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'leads_last_seen_$currentUid',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Stream<int> unreadCountStream() {
    if (currentUid == null) return Stream.value(0);

    final since = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(days: 7)),
    );

    return _db
        .collectionGroup('comments')
        .where('createdAt', isGreaterThan: since)
        .snapshots()
        .asyncMap((snapshot) async {
          final prefs = await SharedPreferences.getInstance();
          final lastSeenMs = prefs.getInt('leads_last_seen_$currentUid') ?? 0;
          final lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenMs);

          print('=== NOTIF DEBUG ===');
          print('Total comments in 7 days: ${snapshot.docs.length}');
          print('Last seen: $lastSeen');

          final count = snapshot.docs.where((doc) {
            final data = doc.data();
            final uid = data['uid'] as String?;
            final createdAt = data['createdAt'] as Timestamp?;

            print('uid: $uid | myUid: $currentUid | createdAt: $createdAt');

            if (uid == currentUid) return false;
            if (createdAt == null) return false;
            return createdAt.toDate().isAfter(lastSeen);
          }).length;

          print('Unread count: $count');
          return count;
        });
  }
}
