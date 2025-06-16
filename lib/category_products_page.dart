import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CategoryProductsPage extends StatelessWidget {
  final String categoryName;
  const CategoryProductsPage({super.key, required this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Produk: $categoryName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: categoryName)
        .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Terjadi kesalahan'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = snapshot.data!.docs;

          if (products.isEmpty) {
            return const Center(child: Text('Tidak ada produk'));
          }

          return ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final data = products[index].data() as Map<String, dynamic>;
              final name = data['product']?.toString() ?? 'No Name';
              final sku = data['sku']?.toString() ?? 'No SKU';
              final quantity = data['quantity']?.toString() ?? '0';

              return ListTile(
                title: Text(name),
                subtitle: Text('SKU: $sku - Jumlah: $quantity'),
              );
            }
          );
        },
      ),
    );
  }
}