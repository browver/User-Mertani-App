import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_app/menu_dashboard.dart';
import 'package:user_app/notification_service.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String searchQuery = '';

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if(!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // Method to get borrowed items count for a specific user
  Stream<Map<String, int>> _getUserBorrowedStats(String username) {
    return FirebaseFirestore.instance
        .collection('borrowed')
        .where('by', isEqualTo: username)
        .snapshots()
        .map((snapshot) {
      int totalBorrowed = 0;
      int activeBorrowed = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0) as int;
        final status = data['status'] ?? '';
        
        totalBorrowed += amount;
        if (status == 'dipinjam') {
          activeBorrowed += amount;
        }
      }
      
      return {
        'total': totalBorrowed,
        'active': activeBorrowed,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        title: Text('Kelola Pengguna', style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        )),
        backgroundColor: Colors.blue[600],
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              showMenu(
                context: context,
                position: RelativeRect.fromLTRB(
                  MediaQuery.of(context).size.width - 100,
                  kToolbarHeight,
                  0,
                  0,
                ),
                items: [
                  PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: const [
                        Icon(Icons.logout, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
              ).then((value) {
                if (value == 'logout') {
                  _logout();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Search Section
          Container(
            margin: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cari Pengguna',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Masukkan nama pengguna...',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    style: GoogleFonts.poppins(fontSize: 14),
                    onChanged: (value) { 
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Users List
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.blue[600]),
                        SizedBox(height: 16),
                        Text(
                          'Memuat data pengguna...',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Filter users based on search query
                final users = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  return username.contains(searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          searchQuery.isEmpty 
                              ? 'Belum ada pengguna terdaftar'
                              : 'Pengguna tidak ditemukan',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (searchQuery.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Coba kata kunci yang berbeda',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data();
                    final username = data['username'] ?? 'No name';
                    final role = data['role'] ?? 'user';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: StreamBuilder<Map<String, int>>(
                        stream: _getUserBorrowedStats(username),
                        builder: (context, statsSnapshot) {
                          final stats = statsSnapshot.data ?? {'total': 0, 'active': 0};
                          
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // User Info Row
                                Row(
                                  children: [
                                    // Avatar
                                    Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        color: role == 'admin' 
                                            ? Colors.red[100] 
                                            : Colors.blue[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        role == 'admin' ? Icons.admin_panel_settings : Icons.person,
                                        color: role == 'admin' ? Colors.red[600] : Colors.blue[600],
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    
                                    // User Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  username,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: role == 'admin' 
                                                      ? Colors.red[100] 
                                                      : Colors.green[100],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  role.toUpperCase(),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: role == 'admin' 
                                                        ? Colors.red[700] 
                                                        : Colors.green[700],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Divisi: ${user.data()['divisi'] != null ? (user.data()['divisi']) : 'Unknown'}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Stats Row
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange[50],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.orange[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${stats['active']}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[700],
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Sedang Dipinjam',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.orange[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.blue[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              '${stats['total']}',
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.blue[700],
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Total Pinjaman',
                                              style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: Colors.blue[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Action Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: Icon(Icons.assignment_outlined, size: 18),
                                    label: Text(
                                      'Lihat Detail Pinjaman',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MyBorrowingsPage(
                                            userName: username, 
                                            isSelf: false
                                          )
                                        )
                                      );
                                    },
                                  ),
                                ),

                                SizedBox(height: 8),

                                // NOTIFICATION
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[600],
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    icon: Icon(Icons.notifications_on_outlined, size: 18),
                                    label: Text(
                                      'Beri Peringatan',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onPressed: () {
                                      NotificationService().showNotification(
                                        title: "Peringatan!!",
                                        body: "Coba coba doang..."
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}