// import 'package:cloud_firestore/cloud_firestore.dart';

// import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  final CollectionReference? products =
    FirebaseFirestore.instance.collection('products');

  // adding Product
  Future<void> addProduct(String product, int quantity, double price) async{
    await products!.add({
      'product':product, 'timestamp': Timestamp.now(),
      'quantity': quantity,
      'price': price}
      );
    await addHistory(
      product,
      'add',
      quantity,
      totalPrice: quantity * price,
    );    
  }

  //read data
  Stream<QuerySnapshot> showProducts() {
    final productsStream =
        products!.orderBy('timestamp', descending: true).snapshots();
    return productsStream;
  }

  // update Product
  Future<void> updateProducts(String docId, String newProduct, int quantity, double price, Timestamp time) async{
    await products!.doc(docId).update({
      'product':newProduct,
      'quantity':quantity,
      'price':price, 
      'timestamp': time});

      await addHistory(
      newProduct,
      'update',
      quantity,
      totalPrice: quantity * price,
    );
  }

// delete
Future<void> deleteProduct(String docId) async {
  final docSnapshot = await products!.doc(docId).get();
  final data = docSnapshot.data() as Map<String, dynamic>?;

  if (data != null) {
    final product = data['product'] ?? '';
    final quantity = data['quantity'] ?? 0;
    final price = data['price'] ?? 0.0;

    await addHistory(
      product,
      'sold',
      quantity,
      totalPrice: quantity * price,
    );
  }

  // Hapus produk
  await products!.doc(docId).delete();
}

  // History
  Future<void> addHistory(String product, String action ,int quantity, {double? totalPrice}) async {
    await FirebaseFirestore.instance.collection('history').add({
      'product':product,
      'quantity':quantity,
      'action':action,
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