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
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController controller = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController priceController = TextEditingController();
  TextEditingController searchController = TextEditingController();
  String searchText = '';

  FirestoreServices firestoreServices = FirestoreServices();

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
              child: pw.Text("Product List", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
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
        return AlertDialog(
          title: Text(
            "Add product",
            style: GoogleFonts.alexandria(fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(hintText: 'product here...'),
                style: GoogleFonts.alexandria(),
                controller: controller,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'quantity here...'),
                keyboardType: TextInputType.number,
                controller: quantityController,
              ),
              TextField(
                decoration: InputDecoration(hintText: 'price per unit here...'),
                keyboardType: TextInputType.number,
                controller: priceController,
              ),
            ],
          ),

          // Add and Update Product
          actions: [
            ElevatedButton(
              onPressed: () {
                if (docId == null) {
                  final product = controller.text.trim();
                  final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
                  final rawPrice = priceController.text.trim();
                  final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
                  final price = double.tryParse(normalizedPrice) ?? 0.0;

                  firestoreServices.addProduct(product, quantity,price);
                // update 
                } else {
                  final product = controller.text.trim();
                  final quantity = int.tryParse(quantityController.text.trim()) ?? 0;
                  final rawPrice = priceController.text.trim();
                  final normalizedPrice = rawPrice.replaceAll('.', '').replaceAll(',', '.');
                  final price = double.tryParse(normalizedPrice) ?? 0.0;

                  firestoreServices.updateProducts(docId, product, quantity, price, time!);
                }
                controller.clear();
                quantityController.clear();
                priceController.clear();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.purple[50],
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.purple[50],
        title: Text(
          "Products",
          style: GoogleFonts.alexandria(),
        ),
        actions: [
          IconButton(
              icon: Icon(Icons.picture_as_pdf, color: Colors.purple),
              tooltip: 'Export to PDF',
                onPressed: exportToPDF,
                ),
          IconButton(
            icon: Icon(Icons.history, color:Colors.purple),
            onPressed: () {
              Navigator.push(
                context, MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
            },)
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.purple[100],
        label: Text(
          'add',
          style: GoogleFonts.alexandria(fontSize: 18),
        ),
        icon: Icon(Icons.add),
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
          hintText: 'Search product name...',
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
            Expanded(
              // Show Products
              child: StreamBuilder(
                stream: FirestoreServices().showProducts(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    List productList = snapshot.data!.docs;
                  //Filter product search
                  if (searchText.isNotEmpty) {
                    productList = productList.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['product'].toString().toLowerCase();
                      return name.contains(searchText);
                    }).toList();
                  }

            return ListView.builder(
              itemCount: productList.length,
              itemBuilder: (context, index) {
                DocumentSnapshot document = productList[index];
                String docId = document.id;
                Map<String, dynamic> data =
                    document.data() as Map<String, dynamic>;
                String product = data['product'];
                int quantity = data['quantity'] ?? 0;
                double price = (data['price'] != null) ? data['price'].toDouble() : 0.0;
                Timestamp time = data['timestamp'];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        tileColor: Colors.purple[100],
                        title :Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product,
                              style: GoogleFonts.alexandria(
                                textStyle: TextStyle(
                                  color: Colors.purple[800], fontSize: 19,
                                ),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Quantity: $quantity',
                              style: GoogleFonts.alexandria(fontSize: 14),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Price: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ').format(price)}',
                              style: GoogleFonts.alexandria(fontSize: 14),
                            )
                          ],
                        ),

                        trailing: Column(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  color: const Color.fromARGB(255, 185, 100, 185),
                                  icon: Icon(Icons.edit),
                                  onPressed: () {
                                    showProductsBox(product, docId, time);
                                  },
                                ),


                                // Delete Product
                                IconButton(
                                    color: Colors.purple[400],
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
                                                    firestoreServices.updateProducts(docId, product, newQty, price, time);
                                                  } else {
                                                    firestoreServices.deleteProduct(docId);
                                                  }

                                                  firestoreServices.addHistory(product, 'delete', qtytoDelete, totalPrice: totalPrice);
                                                  Navigator.pop(context);
                                                } 
                                              },
                                              child: Text("OK"),
                                              ),
                                            ],
                                          );
                                        });
                                    },
                                    icon: Icon(Icons.sell))
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            time.toDate().hour.toString(),
                            style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold),
                          ),
                          Text(":"),
                          Text(
                            time.toDate().minute.toString(),
                            style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
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