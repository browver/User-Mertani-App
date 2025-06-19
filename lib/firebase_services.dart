// import 'package:cloud_firestore/cloud_firestore.dart';

// import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_2/category_model.dart';

class FirestoreServices {
  final CollectionReference? categories =
    FirebaseFirestore.instance.collection('categories');
  final CollectionReference? products =
    FirebaseFirestore.instance.collection('products');
  final CollectionReference? components =
    FirebaseFirestore.instance.collection('components');
  final CollectionReference? sensors =
    FirebaseFirestore.instance.collection('sensors');
  final CollectionReference? loggers =
    FirebaseFirestore.instance.collection('loggers');


  // Category default seeder
  Future<void> seedDefaultCategories() async {
    final existing = await categories!.get();
    if (existing.docs.isEmpty) {
      await addCategory('sensor', Icons.sensors.codePoint);
      await addCategory('logger', Icons.developer_board.codePoint);
      await addCategory('component', Icons.memory.codePoint);
    }
  }

  // adding Category
  Future<void> addCategory(String name, int iconCode) async {
    await categories!.doc(name).set({
      'name' : name,
      'icon' : iconCode,
    });
  }
  
  // takes all categories as a stream
  Stream<List<CategoryModel>> getCategories() {
    return categories!.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CategoryModel.fromMap({
          'id': doc.id,
          ...data,
        });
      }).toList();
    });
  }

  // delete category by id
  Future<void> deleteCategory(String docId) async {
    await categories!.doc(docId).delete();
  }

  // delete all products in a category
  Future<void> deleteCategoryWithProducts(String categoryName) async {
    await categories!.doc(categoryName).delete();

    final productsQuery = await products!
        .where('category', isEqualTo: categoryName)
        .get();

    for (final doc in productsQuery.docs) {
      await doc.reference.delete();
    }
  }

  // adding Product
  Future<void> addProduct(String name, int quantity, double price, String sku, String category) async{
    final data = {
      'product':name,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'category': category,  
      'timestamp': FieldValue.serverTimestamp()
    };
    
    // add to collections
    await products!.add(data);

    final categoryRef = FirebaseFirestore.instance.collection('categories').doc(category);
    await categoryRef.collection('products').add(data);

    // add to history
    await addHistory(
      name,
      'add',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );    
  }

  //read data
  Stream<QuerySnapshot> showProducts() {
    final productsStream = products!.orderBy('timestamp', descending: true).snapshots();
    return productsStream;
  }

  //read data by category
  Stream<QuerySnapshot> getProductsByCategory(String categoryName) {
    return FirebaseFirestore.instance
        .collection('products')
        .where('category', isEqualTo: categoryName)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // update Product
  Future<void> updateProducts(String docId, String newProduct, int quantity, double price, String sku, String category,Timestamp time) async{
    await products!.doc(docId).update({
      'product':newProduct,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'category': category,
      'timestamp': time});

      await addHistory(
      newProduct,
      'update',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

  // delete Product
  Future<void> deleteProduct(String docId) async {
    final docSnapshot = await products!.doc(docId).get();
    final data = docSnapshot.data() as Map<String, dynamic>?;

    if (data != null) {
      final product = data['products'] ?? '';
      final quantity = data['quantity'] ?? 0;
      final price = data['price'] ?? 0.0;
      final sku = data['sku'] ?? '';
      final category = data['category'] ?? '';


      await addHistory(
        product,
        'sold',
        quantity,
        sku,
        category,
        totalPrice: quantity * price,
      );
    }

    // delete all products
    await products!.doc(docId).delete();
  }

  // History
  Future<void> addHistory(String items, String action ,int quantity, String sku, String category,{double? totalPrice}) async {
    await FirebaseFirestore.instance.collection('history').add({
      'items':items,
      'quantity':quantity,
      'action':action,
      'sku': sku,
      'category': category,
      'total_price': totalPrice,
      'timestamp':Timestamp.now(),
    });
  }

  // Delete History
  Future<void> deleteAllHistory() async {
    final historyCollection = FirebaseFirestore.instance.collection('history');

    final snapshots = await historyCollection.get();
    for (var doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
