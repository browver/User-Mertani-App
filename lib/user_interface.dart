import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Warehouse Users', style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        )),
        backgroundColor: Colors.blue,
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
      // Search Products History
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column( 
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search Username..',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
                  ),
                  onChanged: (value) { 
                    setState(() {
                      searchQuery = value.toLowerCase();
                  });
                  },
                ),
              ],
            ),
          ), 
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                .collection('users')
                .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    // Search Filter change
                    final users = snapshot.data!.docs.where((doc) {
                      final data = doc.data();
                      final username = (data['username'] ?? '').toString().toLowerCase();
                      return username.contains(searchQuery);
                    }).toList();

                    if (users.isEmpty) {
                      return const Center(child: Text("Tidak ada pengguna."));
                    }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final data = user.data();

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(data['username'] ?? 'No name'),
                      subtitle: Text("Role: ${data['role']}"),
                      trailing: ElevatedButton(
                        onPressed: () {
                          // nanti diganti pake borrow function
                          debugPrint("Pinjam oleh ${data['username']}");
                        }, child: const Text("Pinjam")),
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