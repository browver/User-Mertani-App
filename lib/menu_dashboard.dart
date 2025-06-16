import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_application_2/homepage.dart';
import 'package:flutter_application_2/logger.dart';
import 'package:flutter_application_2/sensor.dart';
import 'package:flutter_application_2/history_page.dart';
import 'package:flutter_application_2/firebase_services.dart';
// import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';


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

  Future<void> _logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('isLoggedIn'); 
  if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }


// Fungsi pemanggilan add
  void showAddProductDialog(BuildContext context) {
  final TextEditingController controller = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController skuController = TextEditingController();
  String selectedCategory = 'component';
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
              DropdownButtonFormField<String>(
                value: selectedCategory,
                items: ['sensor', 'logger', 'component']
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

              if (product.isNotEmpty && sku.isNotEmpty) {
                if (selectedCategory == 'sensor') {
                  await firestoreServices.addSensor(product, quantity, price, sku, selectedCategory);
                } else if (selectedCategory == 'logger') {
                  await firestoreServices.addLogger(product, quantity, price, sku, selectedCategory);
                } else {
                  await firestoreServices.addComponent(product, quantity, price, sku, selectedCategory);
                }
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
                  _buildGridItem(
                    context,
                    'Sensor',
                    Icons.sensors,
                    const Color(0xFFFF8C00),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SensorPage())
                      );
                    },
                  ),
                  _buildGridItem(
                    context,
                    'Logger',
                    Icons.memory,
                    const Color(0xFFFF8C00),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoggerPage())
                      );
                    },
                  ),
                  _buildGridItem(
                    context,
                    'Component',
                    Icons.category,
                    const Color(0xFFFF8C00),
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HomePage())
                      );
                    },
                  ),
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
                  _buildGridItem(
                    context,
                    'Borrowed',
                    Icons.people_outline,
                    const Color(0xFFFF8C00),
                    () {},
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF8C00), Color(0xFFFF7700)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8C00).withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            showAddProductDialog(context);
          },
          child: const Icon(
            Icons.add,
            color: Colors.white,
            size: 28,
          ),
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