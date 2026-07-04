import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rtstrack/auth/login_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rtstrack/services/task_services.dart';

import 'services/auth_services.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _taskService = TaskService();

  late final Stream<QuerySnapshot> _myTasksStream;
  Map<String, dynamic>? _userData;
  bool _loadingUser = true;

  static const _bg = Color(0xFFF4F5FB);
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _myTasksStream = _taskService.getAllMyTasks();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('uid');

    if (uid != null) {
      final data = await _authService.getUserData(uid);
      if (!mounted) return;
      setState(() {
        _userData = data;
        _loadingUser = false;
      });
    } else {
      if (!mounted) return;
      setState(() => _loadingUser = false);
    }
  }

  Widget _initialsAvatar(String name, {double radius = 36}) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF111827),
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loadingUser) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = (_userData?['name'] ?? '').toString();
    final email = (_userData?['email'] ?? '').toString();
    final role = (_userData?['role'] ?? '').toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                _initialsAvatar(name, radius: 40),
                const SizedBox(height: 14),
                Text(
                  name.isEmpty ? 'Unnamed' : name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? 'No email' : email,
                  style: const TextStyle(color: _subtitle, fontSize: 13),
                ),
                const SizedBox(height: 10),
                if (role.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EBFD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2F6FED),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Task Overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _subtitle,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: _myTasksStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Task stats load nahi ho payi: ${snapshot.error}',
                  style: const TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 12,
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data!.docs;
              final total = docs.length;
              final completed = docs.where((d) {
                final data = d.data() as Map<String, dynamic>;
                return data['status'] == 'completed';
              }).length;
              final active = total - completed;

              return Row(
                children: [
                  _statCard(
                    'Total',
                    '$total',
                    const Color(0xFF374151),
                    const Color(0xFFE5E9F5),
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    'Active',
                    '$active',
                    const Color(0xFF2F6FED),
                    const Color(0xFFE3EBFD),
                  ),
                  const SizedBox(width: 12),
                  _statCard(
                    'Done',
                    '$completed',
                    const Color(0xFF16A34A),
                    const Color(0xFFDCFCE7),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await _authService.logout();
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Agar drawer se aaye (Navigator.push) toh Scaffold chahiye
    // Agar bottom nav se aaye toh parent ka Scaffold use hoga
    final bool hasScaffold = Scaffold.maybeOf(context) != null;

    if (hasScaffold) {
      // Bottom nav se — seedha body return karo
      return _body();
    }

    // Drawer se — apna Scaffold wrap karo
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: _heading),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _heading,
          ),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }
}
