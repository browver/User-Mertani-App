import 'package:flutter/material.dart';
import 'package:user_app/homepage.dart';
import 'package:user_app/history_page.dart';
import 'package:user_app/firebase_services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Selamat Pagi";
    } else if (hour >= 12 && hour < 17) {
      return "Selamat Siang";
    } else if (hour >= 17 && hour < 19) {
      return "Selamat Sore";
    } else {
      return "Selamat Malam";
    }
  }

  List<String> categories = [];
  String? selectedFilterCategory;
  String selectedCategory = '';
  String? role;
  String? userName;
  int totalBorrowedItems = 0;
  int totalAvailableItems = 0;

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    FirestoreServices().getCategories().listen((catList) {
      setState(() {
        categories = catList.map((cat) => cat.name).toList();
        categoryIcons = {for (var cat in catList) cat.name: cat.icon};
      });
    });

    _loadRole();
    _loadUserInfo();
    _loadStats();
  }

  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? 'user';
    });
  }

  void _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('username') ?? 'User';
    });
  }

// New method to get real-time borrowed items count
  Stream<int> _getBorrowedItemsStream() async* {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString('username') ?? '';

    yield* FirebaseFirestore.instance
      .collection('borrowed')
      .where('by', isEqualTo: currentUsername)
      .where('status', isEqualTo: 'borrow')
      .snapshots()
      .map((snaphsot) => snaphsot.docs.length);
  }

// New method to get real-time available items count
  Stream<int> _getAvailableItemsStream() {
    return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((snapshot){
        int availableCount = 0;
        for(var doc in snapshot.docs) {
          final data = doc.data();
          final quantity = data['quantity'];
          if(quantity > 0){
            availableCount++;
          }
        }
        return availableCount;
      });
  }

  void _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUserName = prefs.getString('username') ?? '';

      // Get total borrowed items by current user
      final borrowedSnapshot = await FirebaseFirestore.instance
          .collection('borrowed')
          .where('by', isEqualTo: currentUserName)
          .where('status', isEqualTo: 'borrow')
          .get();

      // Get total available items
      final productsSnapshot = await FirebaseFirestore.instance
          .collection('products')
          .get();

      int availableCount = 0;
      for (var doc in productsSnapshot.docs) {
        final data = doc.data();
        final quantity = data['quantity'] ?? 0;
        if (quantity > 0) {
          availableCount++;
        }
      }

      setState(() {
        totalBorrowedItems = borrowedSnapshot.docs.length;
        totalAvailableItems = availableCount;
      });
    } catch (e) {
      // print('Error loading stats: $e');
    }
  }

  Map<String, IconData> categoryIcons = {};

  // Get User
  Future<String> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'Unknown';
    
  }

  // Admin only - Add Product Dialog
  void showAddProductDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    final TextEditingController quantityController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    final TextEditingController skuController = TextEditingController();
    String selectedCategory = categories.isNotEmpty ? categories.first : '';
    final firestoreServices = FirestoreServices();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Tambah Produk",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Nama Produk',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  controller: controller,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'SKU',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  controller: skuController,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Jumlah',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  controller: quantityController,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Harga',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  keyboardType: TextInputType.number,
                  controller: priceController,
                  style: GoogleFonts.poppins(),
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: categories.contains(selectedCategory) ? selectedCategory : null,
                  items: categories
                      .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(cat.toUpperCase(), style: GoogleFonts.poppins())))
                      .toList(),
                  onChanged: (value) {
                    selectedCategory = value!;
                  },
                  decoration: InputDecoration(
                    hintText: 'Kategori',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Batal", style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final product = controller.text.trim();
                final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
                final rawPrice = priceController.text.trim();
                final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
                final price = double.tryParse(normalizedPrice) ?? 0.0;
                final sku = skuController.text.trim();
                final byId = await getCurrentUserName();

                if (product.isNotEmpty && sku.isNotEmpty) {
                  await firestoreServices.addProduct(product, quantity, price, sku, selectedCategory, '', byId);
                  _loadStats(); // Refresh stats
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text("Tambah", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[600],
        title: Text(
          'BorrowApp Dashboard',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          _loadStats();
        },
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Welcome Header Section
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.person,
                          size: 28,
                          color: Colors.blue[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${getGreeting()}, ${userName ?? 'User'}!',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == 'admin' 
                                ? 'Kelola barang dengan mudah'
                                : 'Pinjam barang yang Anda butuhkan',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Cards (User specific)
              if (role == 'user')
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: _getBorrowedItemsStream(),
                          builder: (context, snapshot) {
                            final borrowedCount = snapshot.data ?? 0;
                            return Container(
                            padding: EdgeInsets.all(16),
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
                            child: Column(
                              children: [
                                Icon(
                                  Icons.assignment_outlined,
                                  size: 32,
                                  color: Colors.orange[600],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '$borrowedCount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[600],
                                  ),
                                ),
                                Text(
                                  'Sedang Dipinjam',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: _getAvailableItemsStream(),
                          builder: (context, snapshot){
                            final availableCount = snapshot.data ?? 0;
                            return Container(
                              padding: EdgeInsets.all(16),
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
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 32,
                                  color: Colors.green[600],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '$availableCount',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[600],
                                  ),
                                ),
                                Text(
                                  'Jenis Barang Tersedia',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

              SizedBox(height: 24),

              // Quick Access Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      role == 'admin' ? 'Kelola Inventori' : 'Akses Cepat',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePage()),
                          );
                        },
                        icon: Icon(Icons.arrow_forward, size: 16),
                        label: Text(
                          'Lihat Semua',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),

              // Main Menu Grid
              if (categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: role == 'admin' ? 3 : 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: role == 'admin' ? 1.1 : 1.0,
                    children: [
                      // Categories
                      ...categories.map((cat) {
                        final icon = categoryIcons[cat] ?? Icons.category;
                        return _buildGridItem(
                          context,
                          cat,
                          icon,
                          Colors.blue[600]!,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HomePage(selectedCategoryFromOutside: cat),
                              ),
                            );
                          },
                        );
                      }),

                      // Browse all items (User)
                      // if (role == 'user')
                      //   _buildGridItem(
                      //     context,
                      //     'Semua Barang',
                      //     Icons.inventory_2_outlined,
                      //     Colors.green[600]!,
                      //     () {
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(builder: (context) => const HomePage()),
                      //       );
                      //     },
                      //   ),

                      // My Borrowings (User)
                      if (role == 'user')
                        _buildGridItem(
                          context,
                          'Pinjaman Saya',
                          Icons.assignment_outlined,
                          Colors.orange[600]!,
                          () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => MyBorrowingsPage()),
                            );
                          },
                        ),

                      // History
                      _buildGridItem(
                        context,
                        'Riwayat',
                        Icons.history,
                        Colors.purple[600]!,
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const HistoryPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 100), // Space for FAB
            ],
          ),
        ),
      ),
      floatingActionButton: role == 'admin'
          ? SpeedDial(
              icon: Icons.add,
              activeIcon: Icons.close,
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              overlayOpacity: 0.4,
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.category),
                  label: 'Kelola Kategori',
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  onTap: () {
                    Navigator.pushNamed(context, '/category');
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.add_box),
                  label: 'Tambah Produk',
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue[600],
                  onTap: () {
                    showAddProductDialog(context);
                  },
                ),
              ],
            )
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                );
              },
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              icon: Icon(Icons.search),
              label: Text(
                'Cari Barang',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SizedBox.expand(
          child : Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                flex: 2,
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

// My Borrowings Page (jika belum ada)
class MyBorrowingsPage extends StatelessWidget {
  const MyBorrowingsPage({super.key});
  Future<String> getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null) return 'Unknown';

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['username'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  DateTime? parseBorrowDate(dynamic borrowDateData) {
    try {
      if (borrowDateData is Timestamp) {
        return borrowDateData.toDate();
      } else if (borrowDateData is String) {
        return DateTime.parse(borrowDateData);
      } else if (borrowDateData == null) {
        return DateTime.now();
      }
    } catch (e) {
      return DateTime.now();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue[600],
        title: Text(
          'Pinjaman Saya',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<String>(
        future: getCurrentUserName(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('borrowed')
                .where('by', isEqualTo: userSnapshot.data!)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                List borrowings = snapshot.data!.docs;

                if (borrowings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Belum ada pinjaman',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: borrowings.length,
                  itemBuilder: (context, index) {
                    final doc = borrowings[index];
                    final borrowing = borrowings[index].data() as Map<String, dynamic>;
                    final borrowDate = parseBorrowDate(borrowing['borrowDate'])?? DateTime.now();
                    final status = borrowing['status'] ?? 'borrow';
                    final productId = borrowing['productId'] ?? '';
                    final returnQuantity = borrowing['quantity'] ?? 0;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    borrowing['productName'] ?? 'Unknown Product',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: status == 'borrow'
                                        ? Colors.orange[100]
                                        : Colors.green[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    status.toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: status == 'borrow'
                                          ? Colors.orange[800]
                                          : Colors.green[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Jumlah: ${borrowing['quantity']} unit',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Dipinjam: ${DateFormat('dd MMM yyyy, HH:mm').format(borrowDate)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (borrowing['notes'] != null && borrowing['notes'].toString().isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Catatan: ${borrowing['notes']}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),

                              if(status == 'borrow')...[
                                SizedBox(height: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadiusGeometry.circular(12),
                                      )
                                    ),
                                    icon: Icon(Icons.keyboard_return),
                                    label: Text('Kembalikan'),
                                    onPressed: () async {
                                      final firestore = FirestoreServices();

                                      if(productId.isEmpty) {
                                        if(!context.mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Gagal: Id tidak ditemukan'))
                                        );
                                        return;
                                      }
                                      await firestore.returnProduct(
                                        docId: borrowing['productId'] ?? 'Unknown Product', 
                                        returnQuantity: returnQuantity);
                                      
                                      await FirebaseFirestore.instance
                                        .collection('borrowed')
                                        .doc(doc.id)
                                        .update({'status' : 'dikembalikan'});

                                      if(!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Barang berhasil dikembalikan'),
                                        backgroundColor:  Colors.green[600],
                                        )
                                      );
                                    },
                                  )
                              ]
                          ],
                        ),
                      ),
                    );
                  },
                );
              } else {
                return Center(
                  child: CircularProgressIndicator(color: Colors.blue[600]),
                );
              }
            },
          );
        },
      ),
    );
  }
}