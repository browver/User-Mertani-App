// import 'package:flutter/cupertino.dart';
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/homepage.dart';
// import 'package:flutter_application_2/logger.dart';
// import 'package:flutter_application_2/product_by_category.dart';
// import 'package:flutter_application_2/sensor.dart';
import 'package:flutter_application_2/history_page.dart';
import 'package:flutter_application_2/firebase_services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
// import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';




class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return "Good Morning";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon";
    } else if (hour >= 17 && hour < 18) {
    return "Good Evening";
    } else {
      return "Good Night";
    }
  }

// define category
  List<String> categories = [];
  String? selectedFilterCategory;
  String selectedCategory = '';
  String? role;


  Future<void> _logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if(!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context,'/login', (route) => false);
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
  }
    void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? 'user';
    });
  }

  Map<String, IconData> categoryIcons = {};

  // Get User
Future<String> getCurrentUserName() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('userId');

  if (userId == null) return 'Unknown';

  final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
  if (doc.exists) {
    final data = doc.data();
    return data?['name'] ?? 'Unknown';
  }
  return 'Unknown';
}


// Fungsi pemanggilan add
  void showAddProductDialog(BuildContext context) {
  final TextEditingController controller = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  String selectedCategory = categories.isNotEmpty ? categories.first: '';
  final firestoreServices = FirestoreServices();
  
    showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("Tambah Produk"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(hintText: 'Nama Produk'),
                controller: controller,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'SKU'),
                controller: skuController,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'Jumlah'),
                keyboardType: TextInputType.number,
                controller: quantityController,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'Harga'),
                keyboardType: TextInputType.number,
                controller: priceController,
              ),
              
  // Dropdown Kategori
              DropdownButtonFormField<String>(
                value: categories.contains(selectedCategory)? selectedCategory: null,
                items: categories
                    .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.toUpperCase())))
                    .toList(),
                onChanged: (value) {
                  selectedCategory = value!;
                },
                decoration: InputDecoration(hintText: 'Kategori'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Batal"),
          ),
          
          ElevatedButton(
            onPressed: () async {
              final product = controller.text.trim();
              final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
              final rawPrice = priceController.text.trim();
              final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
              final price = double.tryParse(normalizedPrice) ?? 0.0;
              final sku = skuController.text.trim();
              final byId = await getCurrentUserName();

              if (product.isNotEmpty && sku.isNotEmpty) {
                await firestoreServices.addProduct(product, quantity, price, sku, selectedCategory, byId ,'');
              }

              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text("Tambah"),
          ),
        ],
      );
    },
  );
  }


// UI Mertani
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFF8C00),
        title: const Text(
          'Mertani Stock', 
          style: TextStyle(
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
                        Icon(Icons.logout, size: 18),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C00), Color(0xFFFF7700)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C00).withOpacity(0.3),
                    blurRadius: 10,
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
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8C00),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${getGreeting()} today',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Be part of nature protect the future',
                          style: TextStyle(
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
            
            // Grid Section
          if (categories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
                children: [
                  // _buildGridItem(
                  //   context,
                  //   'Sensor',
                  //   Icons.memory,
                  //   const Color(0xFFFF8C00),
                  //   () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (context) => const HomePage())
                  //     );
                  //   },
                  // ),
                  // _buildGridItem(
                  //   context,
                  //   'Logger',
                  //   Icons.memory,
                  //   const Color(0xFFFF8C00),
                  //   () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (context) => const HomePage())
                  //     );
                  //   },
                  // ),
                  // _buildGridItem(
                  //   context,
                  //   'Component',
                  //   Icons.category,
                  //   const Color(0xFFFF8C00),
                  //   () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(builder: (context) => const HomePage())
                  //     );
                  //   },
                  // ),
                // dynamic category the final
                ...categories.map((cat) {
                  final icon = categoryIcons[cat] ?? Icons.category;
                  return _buildGridItem(
                    context, cat, 
                    icon, Color(0xFFFF8C00),
                    () {
                      Navigator.push(context, 
                      MaterialPageRoute(builder: (_) => HomePage(selectedCategoryFromOutside: cat)));
                    }
                  );
                }),
                // History + Borrow
                _buildGridItem(
                    context,
                    'History',
                    Icons.history,
                    const Color(0xFFFFA500),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HistoryPage())
                      );
                    },
                  ),
                // _buildGridItem(
                //     context,
                //     'Borrowed',
                //     Icons.people_outline,
                //     const Color(0xFFFF8C00),
                //     () {},
                //   ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
          floatingActionButton: SpeedDial(
            icon: Icons.add,
            activeIcon: Icons.close,
            backgroundColor: const Color(0xFFFF8C00),
            foregroundColor: Colors.white,
            overlayOpacity: 0.4,
            children: [
              SpeedDialChild(
                child: const Icon(Icons.category),
                label: role == 'admin' ? 'Tambah Kategori' : 'Kategori',
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                onTap: () {
                  Navigator.pushNamed(context, '/category');
                },
              ),
              if (role == 'admin')
              SpeedDialChild(
                child: const Icon(Icons.add_box),
                label: 'Tambah Produk',
                foregroundColor: Colors.white,
                backgroundColor: Colors.orange,
                onTap: () {
                  showAddProductDialog(context);
                },
              ),
            ],
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
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}