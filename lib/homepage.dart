import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:user_app/firebase_services.dart';
// import 'package:flutter_application_2/history_page.dart';
import 'package:google_fonts/google_fonts.dart';
// import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  final bool openAddForm;
  final String? selectedCategoryFromOutside;
  
  const HomePage({super.key, this.openAddForm = false, this.selectedCategoryFromOutside});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController controller = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  TextEditingController skuController = TextEditingController();
  TextEditingController imageUrlController = TextEditingController();
  TextEditingController borrowQuantityController = TextEditingController();
  TextEditingController borrowNotesController = TextEditingController();

  String searchText = '';
  String? selectedFilterCategory;
  String selectedCategory = '';
  String? role;
  String? imageUrl;
  String? currentUsername;
  final picker = ImagePicker();

  FirestoreServices firestoreServices = FirestoreServices();
  List<String> categories = [];

  // Get User
  Future<String> getCurrentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username') ?? 'Unknown';
  }

  // Show Borrow Dialog
  Future<void> showBorrowDialog(String productName, String docId, int availableQuantity, String sku, String category, String imageUrl, double price) async {
    borrowQuantityController.clear();
    borrowNotesController.clear();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.shopping_bag_outlined, color: Colors.blue[600]),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pinjam Barang',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info Card
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tersedia: $availableQuantity unit',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              
              // Quantity Input
              TextField(
                controller: borrowQuantityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Jumlah yang dipinjam',
                  hintText: 'Masukkan jumlah (max: $availableQuantity)',
                  prefixIcon: Icon(Icons.numbers, color: Colors.blue[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
              SizedBox(height: 16),
              
              // Notes Input
              TextField(
                controller: borrowNotesController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Keperluan peminjaman...',
                  prefixIcon: Icon(Icons.note_alt_outlined, color: Colors.blue[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final borrowQty = int.tryParse(borrowQuantityController.text.trim()) ?? 0;
                final notes = borrowNotesController.text.trim();
                final totalPrice = borrowQty * price;
                
                if (borrowQty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Masukkan jumlah yang valid'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                if (borrowQty > availableQuantity) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Jumlah melebihi stok tersedia'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                try {
                  final borrowerName = await getCurrentUsername();
                  
                  // Add borrow record
                  await FirebaseFirestore.instance.collection('borrowed').add({
                    'productName': productName,
                    'productId': docId,
                    'sku': sku,
                    'category': category,
                    'quantity': borrowQty,
                    'by': borrowerName,
                    'borrowDate': Timestamp.now(),
                    'status': 'borrow',
                    'notes': notes,
                    'imageUrl': imageUrl,
                    'totalPrice' : totalPrice
                  });

                  await firestoreServices.addHistory(
                    productName, 
                    'borrow', 
                    borrowQty, 
                    sku, 
                    category, 
                    imageUrl, 
                    borrowerName,
                    totalPrice: totalPrice
                  );
                  
                  // Update product quantity
                  final newQuantity = availableQuantity - borrowQty;
                  await FirebaseFirestore.instance.collection('products').doc(docId).update({
                    'quantity': newQuantity,
                  });
                  
                  if(!context.mounted)return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Berhasil meminjam $borrowQty $productName'),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal meminjam barang: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.check_circle_outline),
              label: Text(
                'Pinjam',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    getCurrentUsername();
    
    // Load categories
    firestoreServices.getCategories().listen((catList) {
      setState(() {
        categories = catList.map((cat) => cat.name).toList();
        if (widget.selectedCategoryFromOutside != null && 
            categories.contains(widget.selectedCategoryFromOutside)) {
          selectedFilterCategory = widget.selectedCategoryFromOutside!;
        }
      });
    });
    
    firestoreServices.seedDefaultCategories();
    _loadRole();
  }


  void _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      role = prefs.getString('role') ?? 'user';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue[600],
        title: Text(
          selectedFilterCategory != null
              ? 'Kategori: ${selectedFilterCategory!}'
              : 'Pinjam Barang',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            margin: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari barang yang ingin dipinjam...',
                hintStyle: GoogleFonts.poppins(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.blue[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: GoogleFonts.poppins(),
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase();
                });
              },
            ),
          ),

          // Category Filter Pills
          // if (categories.isNotEmpty)
          //   Container(
          //     height: 50,
          //     margin: EdgeInsets.only(bottom: 16),
          //     child: ListView.builder(
          //       scrollDirection: Axis.horizontal,
          //       padding: EdgeInsets.symmetric(horizontal: 16),
          //       itemCount: categories.length + 1,
          //       itemBuilder: (context, index) {
          //         if (index == 0) {
          //           return Padding(
          //             padding: EdgeInsets.only(right: 8),
          //             child: FilterChip(
          //               label: Text(
          //                 'Semua',
          //                 style: GoogleFonts.poppins(
          //                   color: selectedFilterCategory == null
          //                       ? Colors.white
          //                       : Colors.blue[600],
          //                   fontWeight: FontWeight.w500,
          //                 ),
          //               ),
          //               selected: selectedFilterCategory == null,
          //               onSelected: (selected) {
          //                 setState(() {
          //                   selectedFilterCategory = null;
          //                 });
          //               },
          //               backgroundColor: Colors.white,
          //               selectedColor: Colors.blue[600],
          //               checkmarkColor: Colors.white,
          //             ),
          //           );
          //         }
                  
          //         final category = categories[index - 1];
          //         return Padding(
          //           padding: EdgeInsets.only(right: 8),
          //           child: FilterChip(
          //             label: Text(
          //               category.toUpperCase(),
          //               style: GoogleFonts.poppins(
          //                 color: selectedFilterCategory == category
          //                     ? Colors.white
          //                     : Colors.blue[600],
          //                 fontWeight: FontWeight.w500,
          //               ),
          //             ),
          //             selected: selectedFilterCategory == category,
          //             onSelected: (selected) {
          //               setState(() {
          //                 selectedFilterCategory = selected ? category : null;
          //               });
          //             },
          //             backgroundColor: Colors.white,
          //             selectedColor: Colors.blue[600],
          //             checkmarkColor: Colors.white,
          //           ),
          //         );
          //       },
          //     ),
          //   ),

          // Products Grid
          Expanded(
            child: StreamBuilder(
              stream: FirestoreServices().showProducts(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  List productList = snapshot.data!.docs;

                  // Filter products
                  productList = productList.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['product'].toString().toLowerCase();
                    final category = data['category']?.toString().toLowerCase() ?? '';
                    final quantity = data['quantity'] ?? 0;
                    
                    final matchesSearch = searchText.isEmpty || name.contains(searchText);
                    final matchesCategory = selectedFilterCategory == null || 
                        category == selectedFilterCategory!.toLowerCase();
                    final hasStock = quantity > 0; // Only show items with stock
                    
                    return matchesSearch && matchesCategory && hasStock;
                  }).toList();

                  if (productList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Tidak ada barang tersedia',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Semua barang sedang dipinjam atau stok kosong',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: productList.length,
                    itemBuilder: (context, index) {
                      DocumentSnapshot document = productList[index];
                      String docId = document.id;
                      Map<String, dynamic> data = document.data() as Map<String, dynamic>;
                      
                      String product = data['product']?.toString() ?? 'No Name';
                      String sku = data['sku']?.toString() ?? 'No SKU';
                      String category = data['category']?.toString() ?? 'No category';
                      int quantity = data['quantity'] ?? 0;
                      String imageUrl = data['imageUrl']?.toString() ?? '';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Image
                            Expanded(
                              flex: 3,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                ),
                                child: imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(16),
                                        ),
                                        child: Image.network(
                                          imageUrl,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, loadingProgress) {
                                            if(loadingProgress == null) return child;
                                            return Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: CircularProgressIndicator(
                                                  value: loadingProgress.expectedTotalBytes != null
                                                      ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                      : null,
                                                  color: Colors.blue[600],
                                                  strokeWidth: 2,
                                                  )
                                                )
                                              );
                                          },
                                          errorBuilder: (context, error, stackTrace) =>
                                              Icon(
                                            Icons.image_not_supported,
                                            size: 40,
                                            color: Colors.grey[400],
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.inventory_2_outlined,
                                        size: 40,
                                        color: Colors.blue[600],
                                      ),
                              ),
                            ),
                            
                            // Product Info
                            Expanded(
                              flex: 3,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Tersedia: $quantity',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: quantity > 0 ? Colors.green[600] : Colors.red[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: quantity > 0
                                            ? () {
                                                showBorrowDialog(
                                                  product,
                                                  docId,
                                                  quantity,
                                                  sku,
                                                  category,
                                                  imageUrl,
                                                  data['price'] ?? 0
                                                );
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue[600],
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(vertical: 8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: Icon(Icons.shopping_bag_outlined, size: 16),
                                        label: Text(
                                          'Pinjam',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                } else {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue[600],
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

