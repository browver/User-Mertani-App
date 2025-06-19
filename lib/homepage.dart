// import 'dart:ui';
// import 'dart:ffi';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
// import 'package:flutter/widgets.dart';
import 'package:flutter_application_2/firebase_services.dart';
import 'package:flutter_application_2/history_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


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
  TextEditingController skuController =TextEditingController();

  String searchText = '';
  String? selectedFilterCategory;
  String selectedCategory = '';

  FirestoreServices firestoreServices = FirestoreServices();

  List<String> categories = [];

// Export PDF
Future<void> exportToPDF() async {
  try {
    final pdfDoc = pw.Document();
    final snapshot = await FirebaseFirestore.instance.collection('products').get();
    final products = snapshot.docs;

    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada produk untuk diekspor.")),
      );
      return;
    }

    pdfDoc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text("Products List", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Product', 'Quantity', 'Price'],
              data: products.map((doc) {
                final data = doc.data();
                final name = data['product'] ?? '';
                final qty = data['quantity']?.toString() ?? '0';
                final price = (data['price'] != null)
                    ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(data['price'])
                    : '-';
                return [name, qty, price];
              }).toList(),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdfDoc.save(), filename: 'products.pdf');
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Gagal export PDF: $e")),
    );
  }
}

  // UI Tampilan Products
  void showProductsBox(String? textToedit, String? docId, Timestamp? time) {
    showDialog(
      context: context,
      builder: (context) {
        if (textToedit != null) {
          controller.text = textToedit;
        }
        if (docId != null) {
          FirebaseFirestore.instance.collection('products').doc(docId).get().then((doc) {
            final data = doc.data();
            if (data != null) {
              skuController.text = data['sku'] ?? ''; 
              quantityController.text = data['quantity']?.toString() ?? ''; 
              priceController.text = data['price']?.toString() ?? ''; 
              selectedCategory = data['category'] ?? selectedCategory;
            }
          });
        }
        return AlertDialog(
          title: Text(
            "Add product",
            style: GoogleFonts.alexandria(fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(hintText: 'Nama Barang...'),
                style: GoogleFonts.alexandria(),
                controller: controller,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'SKU...'),
                style: GoogleFonts.alexandria(),
                controller: skuController,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'Jumlah...'),
                keyboardType: TextInputType.number,
                controller: quantityController,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'Harga...'),
                keyboardType: TextInputType.number,
                controller: priceController,
              ),

              // Dropdown Category
              DropdownButtonFormField<String>(
                value: categories.contains(selectedCategory)? selectedCategory: null,
                items: categories
                  .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.toUpperCase())))
                  .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value!;
                  });
                },
                decoration: InputDecoration(hintText: 'Kategori'),
              ),
            ],
          ),

          // Add Product
          actions: [
            ElevatedButton(
              onPressed: () async {
                if (docId == null) {
                  final name = controller.text.trim();
                  final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
                  final rawPrice = priceController.text.trim();
                  final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
                  final price = double.tryParse(normalizedPrice) ?? 0.0;
                  final sku = skuController.text.trim();

                  if (docId == null) {
                    await firestoreServices.addProduct(name, quantity, price, sku, selectedCategory);
                  } else {
                    await firestoreServices.updateProducts(docId, name, quantity, price, sku, selectedCategory, time!);
                  }
          // Update Product
                } else {
                  final product = controller.text.trim();
                  final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
                  final rawPrice = priceController.text.trim();
                  final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
                  final price = double.tryParse(normalizedPrice) ?? 0.0;
                  final sku = skuController.text.trim();
                  
                  firestoreServices.updateProducts(docId, product, quantity, price, sku, selectedCategory, time!);
                }
                controller.clear();
                quantityController.clear();
                priceController.clear();
                skuController.clear();

                if(!mounted) return;
                Navigator.pop(context);
              },
              child: Text(
                'add',
                style: GoogleFonts.alexandria(),
              ),
            )
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    firestoreServices.getCategories().listen((catList) {
      setState(() {
        categories = catList.map((cat) => cat.name).toList();

        if (widget.selectedCategoryFromOutside !=null && categories.contains(widget.selectedCategoryFromOutside)) {
          selectedFilterCategory = widget.selectedCategoryFromOutside!;
        }
      });
    });

    firestoreServices.seedDefaultCategories();

    if (widget.openAddForm) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showProductsBox(null, null, null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.orange[500],
        title: Text(
          "Products",
          style: GoogleFonts.alexandria(
            color: Colors.white
          ),
        ),
        actions: [
          IconButton(
            // Pdf icon
              icon: Icon(Icons.picture_as_pdf, color: Colors.white),
              tooltip: 'Export to PDF',
                onPressed: exportToPDF,
                ),
          IconButton(
            icon: Icon(Icons.history, color:Colors.white),
            onPressed: () {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
            },)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange[500],
        child: Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          showProductsBox(null, null, null);
        },
      ),


  body: Column(
  children: [
    Padding(
      padding: const EdgeInsets.all(10.0),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText: 'Search products name...',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: (value) {
          setState(() {
            searchText = value.toLowerCase();
          });
        },
      ),
    ),

    // Dropdown filter
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButton(
        isExpanded: true,
        hint: Text('Filter by Category'),
        value: selectedFilterCategory,
        items: categories
            .map((cat) => DropdownMenuItem(value: cat, child: Text(cat.toUpperCase())))
            .toList(),
          onChanged: (value) {
            setState(() {
              selectedFilterCategory = value;
            });
          },
        ),
      ),
      

            Expanded(
              // Show Products
              child: StreamBuilder(
                stream: FirestoreServices().showProducts(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    List productList= snapshot.data!.docs;

                  //Filter product search + category
                    productList = productList.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['product'].toString().toLowerCase();
                      final category = data['category']?.toString().toLowerCase() ?? '';
                      final matchesSearch = searchText.isEmpty || name.contains(searchText);
                      final matchesCategory = selectedFilterCategory == null || category == selectedFilterCategory!.toLowerCase();
                      return matchesSearch && matchesCategory;
                    }).toList();

            // ListTile
            return ListView.builder(
              itemCount: productList.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = productList[index];
                String docId = document.id;
                Map<String, dynamic> data =
                    document.data() as Map<String, dynamic>;
                String product = data['product']?.toString()?? 'No Name';
                String sku = data['sku']?.toString()?? 'No SKU';
                String selectedCategory = data['category']?.toString()?? 'No category';
                int quantity = data['quantity'] ?? 0;
                double price = (data['price'] != null) ? data['price'].toDouble() : 0.0;
                Timestamp time = data['timestamp'] ?? Timestamp.now();
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        tileColor: Colors.white,
                        title :Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product,
                              style: GoogleFonts.alexandria(
                                textStyle: TextStyle(
                                  color: Colors.black, fontSize: 19, fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                           SizedBox(height: 4),
                            Text(
                              'SKU: $sku',
                              style: GoogleFonts.alexandria(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Jumlah: $quantity',
                              style: GoogleFonts.alexandria(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Harga: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(price)}',
                              style: GoogleFonts.alexandria(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Ditambahkan: ${DateFormat('dd MMMM yyyy, HH:mm').format(time.toDate())}',
                              style: GoogleFonts.alexandria(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ),

                        trailing: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  color: Colors.orange[500],
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    showProductsBox(product, docId, time);
                                  },
                                ),


                                // Sell product
                                IconButton(
                                    color: Colors.orange[500],
                                    onPressed: () {
                                      TextEditingController deleteQtyController = TextEditingController();

                                      showDialog(
                                        context: context,
                                        builder: (context) {
                                          return AlertDialog(
                                            title: Text('Sell Stock'),
                                            content: TextField(
                                              controller: deleteQtyController,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(hintText: 'Amount'),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                },
                                                child: Text("Cancel"),
                                              ),
                                              TextButton(onPressed: () {
                                                final qtytoDelete = int.tryParse(deleteQtyController.text.trim()) ?? 0;
                                                if (qtytoDelete > 0 && qtytoDelete <= quantity) {
                                                  final newQty = quantity - qtytoDelete;
                                                  final totalPrice = qtytoDelete * price;

                                                  if (newQty > 0) {
                                                    firestoreServices.updateProducts(docId, product, newQty, price, sku, selectedCategory, time);
                                                  } else {
                                                    firestoreServices.deleteProduct(docId);
                                                  }

                                                  firestoreServices.addHistory(product, 'delete', qtytoDelete, sku, selectedCategory, totalPrice: totalPrice);
                                                  Navigator.pop(context);
                                                } 
                                              },
                                              child: Text("OK"),
                                              ),
                                            ],
                                          );
                                        });
                                    },
                                    icon: Icon(Icons.delete))
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            );
          } else {
            return Center(
              child: Text("Nothing to show...add products"),
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