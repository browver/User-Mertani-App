import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:user_app/category_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets.dart';

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


  // Get User
  static Future <String> getCurrentUsername() async {
    try{
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if(userId == null) return 'Unknown';

    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['username'] ?? 'Unknown';
    }

    return 'Unknown';
  } catch(e) {
    return 'Unknown';
  }
  
  }

  // Realtime update borrowed
  Stream<int> getTotalBorrowedByStatusStream(String status){
    return FirebaseFirestore.instance
      .collection('borrowed')
      .where('status', isEqualTo: status)
      .snapshots()
      .map((snapshot) => snapshot.docs.length);
  }

  // Update Latest User History
  Future<void> updateUnknownHistroryEntries() async {
    final currentUsername = await getCurrentUsername();
    final historyCollection = FirebaseFirestore.instance.collection('history');
    final querySnapshot = await historyCollection.where('by', isEqualTo: 'Unknown').get();

    for (final doc in querySnapshot.docs) {
      await doc.reference.update({'by': currentUsername});
    }
  }

  // Image compresser
  Future<File?> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = path.join(
      dir.path,
      'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final xfile = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
    );

    if(xfile != null) {
      final compressedFile =  File(xfile.path);
      // print('Compressed file size: ${await compressedFile.length()} bytes');
      return compressedFile;
    } else {
      // print('compression failed!');
      return null;
    }
  }

// To get the public id from secure url
  String? _extractPublicIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      final fileName = segments.last;
      final dotIndex = fileName.lastIndexOf('.');
      return dotIndex != -1 ? fileName.substring(0, dotIndex) : fileName;
    } catch (e) {
      return null;
    }
  }

// Delete Image
Future<void> _deleteFromCloudinary(String publicId) async {
  const cloudName ='dopauoogt';
  const apiKey = myapikey;
  const apiSecret = myServiceKey;
  
  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final signatureRaw ='public_id=$publicId&timestamp=$timestamp$apiSecret';
  final signature = sha1.convert(utf8.encode(signatureRaw)).toString();

  final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
  final headers = {
    'Content-Type' : 'application/x-www-form-urlencoded',
  };

  await http.post(url, headers: headers, body: {
    'public_id' : publicId,
    'api_key' : apiKey,
    'timestamp' : timestamp.toString(),
    'signature' :signature,
  });
}


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

  // Update Category
  Future<void> updateCategory(String oldName, String newName, int newIconCodePoint) async {
    final categoryRef = FirebaseFirestore.instance.collection('categories');
    final productRef = FirebaseFirestore.instance.collection('products');

    final query = await categoryRef.where('name', isEqualTo: oldName).get();
    for (var doc in query.docs) {
      await doc.reference.update({
        'name':newName,
        'icon':newIconCodePoint,
      });
    }

    // Update all product with the new category
    final productQuery = await productRef.where('category', isEqualTo: oldName).get();
    for (var doc in productQuery.docs) {
      await doc.reference.update({
        'category' : newName,
      });
    }

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
      final productDocs = await products!
        .where('category', isEqualTo: categoryName)
        .get();

      final batch = FirebaseFirestore.instance.batch();
      final categoryRef = FirebaseFirestore.instance.collection('categories').doc(categoryName);
      final subProductsQuery = await categoryRef.collection('products').get();

      for (final doc in productDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final product = data['product'] ?? '';
        final quantity = data['quantity'] ?? 0;
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final sku = data['sku'] ?? '';
        final category = data['category'] ?? '';
        final imageUrl = data['imageUrl'] ?? '';
        final user = await getCurrentUsername();


        await addHistory(product, 'delete', quantity, sku, category, imageUrl, user , totalPrice: quantity * price);
        batch.delete(doc.reference);
      }
      for (final doc in subProductsQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(categoryRef);
      await batch.commit();
  }

  // adding Product
  Future<void> addProduct(String name, int quantity, double price, String sku, String category, String imageUrl, String byUser) async{
    final data = {
      'product':name,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'category': category,
      if (imageUrl.isNotEmpty) 'imageUrl' : imageUrl,
      'by' : byUser, 
      'timestamp': FieldValue.serverTimestamp()
    };
    
    // add to collections
    final docRef = await products!.add(data);
    final categoryRef = FirebaseFirestore.instance.collection('categories').doc(category);
    final user = await getCurrentUsername();
    await categoryRef.collection('products').add({
      ...data,
      'docId' : docRef.id,
      });

    // add to history
    await addHistory(
      name,
      'add',
      quantity,
      sku,
      category,
      imageUrl,
      user,
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
  Future<void> updateProducts(String docId, String newProduct, int quantity, double price, String sku, String oldCategory, String newCategory,String imageUrl,String byUser ,Timestamp time) async{
    final user = await getCurrentUsername();
    
    await products!.doc(docId).update({
      'product':newProduct,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'category': newCategory,
      if (imageUrl.isNotEmpty) 'imageUrl' : imageUrl,
      'by' : user,
      'timestamp': time});

      final newData = {
      'product':newProduct,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'imageUrl' : imageUrl,
      'docId' : docId,
      'by' : user,
      'timestamp': time
      };

      if(oldCategory == newCategory) {
        final subProducts = await categories!
          .doc(newCategory)
          .collection('products')
          .where('docId', isEqualTo: docId)
          .get();

        for (var doc in subProducts.docs) {
          await doc.reference.update(newData);
        }
      } else {
        final oldSubProducts = await categories!
          .doc(oldCategory)
          .collection('products')
          .where('docId', isEqualTo: docId)
          .get();

          for(var doc in oldSubProducts.docs) {
            await doc.reference.delete();
          }

          await categories!
            .doc(newCategory)
            .collection('products')
            .add(newData);
      }

      // await updateProductInCategorySubcollection(docId, sku, newProduct, newCategory, quantity, price, imageUrl);

      if (quantity > 0) {
        await addHistory(
        newProduct,
        'update',
        quantity,
        sku,
        newCategory,
        imageUrl,
        user,
        totalPrice: quantity * price,  
      );
    }
  }

  // Update Product in Category
  Future<void> updateProductInCategorySubcollection(String docId, String sku, String product, String category, int quantity, double price, String imageUrl, String byUser) async {
    final subProducts = await categories!
    .doc(category)
    .collection('products')
    .where('docId', isEqualTo: docId)
    .get();

    for (var doc in subProducts.docs) {
      await doc.reference.update({
        'product' : product,
        'quantity' : quantity,
        'price' : price,
        'imageUrl' : imageUrl,
        'sku' : sku
      });
    }
  }

  // Borrowed Product
  Future<void> borrowProduct({
    required String docId,
    required int borrowQuantity,
  }) async {
    final docSnapshot = await products!.doc(docId).get();
    final data = docSnapshot.data() as Map<String, dynamic>?;

    if(data == null) return;

    final currentQuantity = data['quantity'] ?? 0;
    final newQuantity = currentQuantity - borrowQuantity;

    if(newQuantity <= 0) {
      throw Exception('Stok tidak cukup untuk dipinjam');
    }

    final user = await getCurrentUsername();

    // Update quantity
    await products!.doc(docId).update({
      'quantity' : newQuantity,
      'by' : user,
      'timestamp' : Timestamp.now(),
    });

    final product = data['product'] ?? '';
    final sku = data['sku'] ?? '';
    final category = data['category'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    // add to history
    await addHistory(
      product, 
      'borrow', 
      borrowQuantity, 
      sku, 
      category, 
      imageUrl, 
      user,
      totalPrice: price * borrowQuantity
    );

    await FirebaseFirestore.instance.collection('borrowed').add({
      'product' : product,
      'sku' : sku,
      'category' : category,
      'quantity' : borrowQuantity,
      'imageUrl' : imageUrl,
      'by' : user,
      'borrowed at' : Timestamp.now()
    });
  }

  // Return Product
  Future<void> returnProduct({
    required String docId,
    required int returnQuantity,
  }) async {
    final docSnapshot = await products!.doc(docId).get();
    final data = docSnapshot.data() as Map<String, dynamic>?;
    
    if(data == null) return;

    final currentQuantity = data['quantity'] ?? 0;
    final newQuantity = currentQuantity + returnQuantity;

    final user = await getCurrentUsername();
    final product = data['product'] ?? '';
    final sku = data['sku'] ?? '';
    final category = data['category'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    await products!.doc(docId).update({
      'quantity' : newQuantity,
      'by' : user,
      'timestamp' : Timestamp.now()
    });

    final subProductsSnapshot = await categories!
      .doc(category)
      .collection('products')
      .where('docId', isEqualTo: docId)
      .get();
    
    for(final doc in subProductsSnapshot.docs) {
      await doc.reference.update({
        'quantity' : newQuantity,
        'by' : user,
        'timestamp' : Timestamp.now()
      });
    }

    await addHistory(
      product, 
      'return', 
      returnQuantity, 
      sku, 
      category, 
      imageUrl, 
      user,
      totalPrice: price * returnQuantity
    );
  }

  // delete Product
  Future<void> deleteProduct(String docId) async {
    final docSnapshot = await products!.doc(docId).get();
    final data = docSnapshot.data() as Map<String, dynamic>?;

    if (data != null) {
      final category = data['category'] ?? '';
      final imageUrl = data['imageUrl'] ?? '';
      final product = data['product'] ?? '';
      final quantity = data['quantity'] ?? '';
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final sku = data['sku'] ?? '';

      final user = await getCurrentUsername();
      
      if (imageUrl.isNotEmpty) {
        final publicId = _extractPublicIdFromUrl(imageUrl);
        if (publicId != null) {
          await _deleteFromCloudinary(publicId);
        }
      }

      final categoryRef = FirebaseFirestore.instance.collection('categories').doc(category);
      final subProducts = await categoryRef
          .collection('products')
          .where('docId', isEqualTo: docId)
          .get();
      for (var doc in subProducts.docs) {
        await doc.reference.delete();
      }

      // add to history
      await addHistory(product, 'delete', quantity, sku, category, imageUrl, user, totalPrice: quantity * price);
    }
    // delete all products
    await products!.doc(docId).delete();
  }

  // History
  Future<void> addHistory(String items, String action ,int quantity, String sku, String category, String imageUrl, String byUser ,{double? totalPrice} ) async {
    await FirebaseFirestore.instance.collection('history').add({
      'items':items,
      'quantity':quantity,
      'action':action,
      'sku': sku,
      'category': category,
      'imageUrl' : imageUrl.isNotEmpty ? imageUrl : null,
      'total_price': totalPrice,
      'timestamp':Timestamp.now(),
      'by': byUser,
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
