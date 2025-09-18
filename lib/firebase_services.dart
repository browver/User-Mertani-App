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
  // optional
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CollectionReference? categories =
    FirebaseFirestore.instance.collection('categories');
  final CollectionReference? products =
    FirebaseFirestore.instance.collection('items');
  final CollectionReference? history =
      FirebaseFirestore.instance.collection('history');

  CollectionReference<Map<String, dynamic>> _itemsRef(String categoryId) {
    return FirebaseFirestore.instance
      .collection('categories')
      .doc(categoryId)
      .collection('items');
  }

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

  // get Items
  Stream<QuerySnapshot> getItemsByCategoryId(String categoryId){
    return FirebaseFirestore.instance
    .collection('categories')
      .doc(categoryId)
      .collection('items')
      .orderBy('timestamp', descending: true)
      .snapshots();
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
      return compressedFile;
    } else {
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

    final query = await categoryRef.where('name', isEqualTo: oldName).get();
    for (var doc in query.docs) {
      await doc.reference.update({
        'name':newName,
        'icon':newIconCodePoint,
      });
    
    // Update all product with the new category
    final itemsSnapshot = await doc.reference.collection('items').where('category', isEqualTo: oldName).get();
    for (var doc in itemsSnapshot.docs) {
      await doc.reference.update({
        'category' : newName,
      });
      }
    }
  }
  
  // takes all categories as a stream
  Stream<List<CategoryModel>> getCategories() {
    return categories!.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return CategoryModel.fromFirestore(doc.id, data);
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
      final subProductsQuery = await categoryRef.collection('items').get();

      List<Map<String, dynamic>> historyData = [];

      for (final doc in productDocs.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final product = data['name'] ?? '';
        final amount = data['amount'] ?? 0;
        final price = (data['price'] as num?)?.toDouble() ?? 0.0;
        final sku = data['sku'] ?? '';
        final imageUrl = data['imageUrl'] ?? '';
        
        if (imageUrl.isNotEmpty) {
          final publicId = _extractPublicIdFromUrl(imageUrl);
          if (publicId != null) {
            await _deleteFromCloudinary(publicId);
          }
        }
        
        historyData.add({
          'product': product,
          'amount': amount,
          'price': price,
          'sku': sku,
          'imageUrl': imageUrl,
        });
        
        batch.delete(doc.reference);
      }
      
      for (final doc in subProductsQuery.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(categoryRef);
      
      await batch.commit();
      
      final user = await getCurrentUsername();
      for (var data in historyData) {
        await addHistory(
          data['product'], 
          'delete', 
          data['amount'], 
          data['sku'], 
          categoryName, 
          data['imageUrl'], 
          user, 
          totalPrice: data['amount'] * data['price']
        );
      }
  }

  // adding Product
  Future<void> addProduct(String name, int amount, String sku, String category, String imageUrl, String byUser, {String merk = '', bool hasCustomImage = true}) async{
    final data = {
      'name':name,
      'amount': amount,
      'sku': sku,
      'category': category,
      'merk' : merk,
      'hasCustomImage' : hasCustomImage,
      if (imageUrl.isNotEmpty) 'imageUrl' : imageUrl,
      'by' : byUser, 
      'timestamp': FieldValue.serverTimestamp(),
      'last_updated': FieldValue.serverTimestamp(),
    };
    
    // add to collections
    await products!.doc(sku).set(data);
    final categoryRef = FirebaseFirestore.instance.collection('categories').doc(category);
    await categoryRef.collection('items').doc(sku).set(data);

    // add to history
    final user = await getCurrentUsername();
    await addHistory(
      name,
      'item_added',
      amount,
      sku,
      category,
      imageUrl,
      user,
    );    
  }

  //read data
  Stream<QuerySnapshot> showProducts() {
    return FirebaseFirestore.instance.collectionGroup('items').snapshots();
  }

  //read data by category
  Stream<QuerySnapshot> getProductsByCategory(String categoryName) {
    return FirebaseFirestore.instance
        .collection('items')
        .where('category', isEqualTo: categoryName)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Update Product
  Future<void> updateProducts({
    required String categoryId,
    required String docId,
    required String newName,
    required int amount,
    required double price,
    required String sku,
    required String imageUrl,
    String merk = '',
  }) async {
    final user = await getCurrentUsername();

    final newData = {
      'name': newName,
      'amount': amount,
      'price': price,
      'sku': sku,
      'merk': merk,
      if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
      'by': user,
      'last_updated': FieldValue.serverTimestamp(),
    };

    // Update both collections
    await products!.doc(sku).update(newData);
    await _itemsRef(categoryId).doc(sku).update(newData);

    if (amount > 0) {
      await addHistory(
        newName,
        'update',
        amount,
        sku,
        categoryId,
        imageUrl,
        user,
        totalPrice: amount * price,
      );
    }
  }

  // Update Product in Category
  Future<void> updateProductInCategorySubcollection(String docId, String sku, String product, String category, int amount, double price, String imageUrl, String byUser) async {
    final subProducts = await categories!
    .doc(category)
    .collection('items')
    .where('sku', isEqualTo: sku)
    .get();

    for (var doc in subProducts.docs) {
      await doc.reference.update({
        'name' : product,
        'amount' : amount,
        'price' : price,
        'imageUrl' : imageUrl,
        'sku' : sku
      });
    }
  }

  // Borrowed Product
  Future<void> borrowProduct({
    required String categoryId,
    required String docId,
    required int borrowAmount,
  }) async {
    final docRef = _itemsRef(categoryId).doc(docId);
    final docSnapshot = await docRef.get();
    final data = docSnapshot.data();

    if (data == null) return;

    final currentAmount = data['amount'] ?? 0;
    final newAmount = currentAmount - borrowAmount;

    if (newAmount < 0) {
      throw Exception('Stok tidak cukup untuk dipinjam');
    }

    final user = await getCurrentUsername();

    // Update amount di subcollection
    await docRef.update({
      'amount': newAmount,
      'by': user,
      'last_updated': FieldValue.serverTimestamp(),
    });

    // Update amount di main collection
    // await products!.doc(docId).update({
    //   'amount': newAmount,
    //   'by': user,
    //   'last_updated': FieldValue.serverTimestamp(),
    // });

    final product = data['name'] ?? '';
    final sku = data['sku'] ?? docId;
    final imageUrl = data['imageUrl'] ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    // add to history
    await addHistory(
      product,
      'borrow',
      borrowAmount,
      sku,
      categoryId,
      imageUrl,
      user,
      totalPrice: price * borrowAmount,
    );
  }

  // Return Product
  Future<void> returnProduct({
    required String categoryId,
    required String docId,
    required int returnAmount,
  }) async {
    // Menggunakan sku sebagai docId untuk konsistensi
    final docRef = _itemsRef(categoryId).doc(docId);
    final docSnapshot = await docRef.get();
    final data = docSnapshot.data();

    if (data == null) return;

    final currentAmount = data['amount'] ?? 0;
    final newAmount = currentAmount + returnAmount;

    final user = await getCurrentUsername();
    final product = data['name'] ?? '';
    final sku = data['sku'] ?? docId;
    final imageUrl = data['imageUrl'] ?? '';
    final price = (data['price'] as num?)?.toDouble() ?? 0.0;

    // Update amount di subcollection
    await docRef.update({
      'amount': newAmount,
      'by': user,
      'last_updated': FieldValue.serverTimestamp(),
    });

    // Update amount di main collection
    // await products!.doc(docId).update({
    //   'amount': newAmount,
    //   'by': user,
    //   'last_updated': FieldValue.serverTimestamp(),
    // });

    await addHistory(
      product,
      'return',
      returnAmount,
      sku,
      categoryId,
      imageUrl,
      user,
      totalPrice: price * returnAmount,
    );
  }

  // delete Product
  Future<void> deleteProduct(String docId) async {
    final docSnapshot = await products!.doc(docId).get();
    final data = docSnapshot.data() as Map<String, dynamic>?;

    if (data != null) {
      final category = data['category'] ?? '';
      final imageUrl = data['imageUrl'] ?? '';
      final product = data['name'] ?? '';
      final amount = data['amount'] ?? 0;
      final price = (data['price'] as num?)?.toDouble() ?? 0.0;
      final sku = data['sku'] ?? '';

      final user = await getCurrentUsername();
      
      if (imageUrl.isNotEmpty) {
        final publicId = _extractPublicIdFromUrl(imageUrl);
        if (publicId != null) {
          await _deleteFromCloudinary(publicId);
        }
      }

      final batch = FirebaseFirestore.instance.batch();
      batch.delete(products!.doc(docId));

      final categoryRef = FirebaseFirestore.instance.collection('categories').doc(category);
      final subProducts = await categoryRef
          .collection('items')
          .where('sku', isEqualTo: sku)
          .get();
      for (var doc in subProducts.docs) {
        await doc.reference.delete();
      }

      // add to history
      await batch.commit();
      await addHistory(product, 'delete', amount, sku, category, imageUrl, user, totalPrice: amount * price);
    }
    // delete all products
    await products!.doc(docId).delete();
  }

  // History
  Future<void> addHistory(String items, String action ,int amount, String sku, String category, String imageUrl, String byUser ,{double? totalPrice} ) async {
    await FirebaseFirestore.instance.collection('history').add({
      'name':items,
      'amount':amount,
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



// TESTING SOME FEATURES..

// /// Cleanup data orphaned (main + subcollections)
// Future<void> cleanupOrphanedData() async {
//   print('🧹 Cleanup orphaned data dimulai...');

//   final allCategories = await categories!.get();
//   final validCategories = allCategories.docs.map((doc) => doc.id).toSet();

//   // Cleanup main collection
//   final allProducts = await products!.get();
//   final batchMain = FirebaseFirestore.instance.batch();
//   int deletedMain = 0;

//   for (var doc in allProducts.docs) {
//     final data = doc.data() as Map<String, dynamic>;
//     final category = data['category'] ?? '';
//     if (!validCategories.contains(category)) {
//       batchMain.delete(doc.reference);
//       deletedMain++;
//     }
//   }
//   if (deletedMain > 0) await batchMain.commit();

//   // Cleanup subcollections
//   for (var categoryDoc in allCategories.docs) {
//     final items = await categoryDoc.reference.collection('items').get();
//     final batchSub = FirebaseFirestore.instance.batch();
//     int deletedSub = 0;

//     for (var item in items.docs) {
//       final sku = item['sku'] ?? '';
//       final mainDoc = await products!.doc(sku).get();
//       if (!mainDoc.exists) {
//         batchSub.delete(item.reference);
//         deletedSub++;
//       }
//     }
//     if (deletedSub > 0) await batchSub.commit();
//   }

//   print('✅ Cleanup selesai');
// }

// // ==========================================================================
// /// Sinkronisasi data dari main ke subcollections
// Future<void> syncProducts() async {
//   print('🔄 Sinkronisasi dimulai...');
//   final allProducts = await products!.get();

//   for (var doc in allProducts.docs) {
//     final data = doc.data() as Map<String, dynamic>;
//     final sku = data['sku'] ?? '';
//     final category = data['category'] ?? '';

//     if (sku.isNotEmpty && category.isNotEmpty) {
//       await categories!.doc(category).collection('items').doc(sku).set(data);
//     }
//   }

//   print('✅ Sinkronisasi selesai');
// }

// /// Verifikasi konsistensi data
// Future<void> verifyData() async {
//   final mainCount = (await products!.get()).docs.length;
//   int subCount = 0;

//   final allCategories = await categories!.get();
//   for (var categoryDoc in allCategories.docs) {
//     final subDocs = await categoryDoc.reference.collection('items').get();
//     subCount += subDocs.docs.length;
//   }

//   print('📊 Main: $mainCount | Sub: $subCount');
//   if (mainCount == subCount) {
//     print('✅ Data konsisten');
//   } else {
//     print('⚠️ Data tidak konsisten');
//   }
// }

// /// Backup data ke history
// Future<void> backupProducts() async {
//   print('💾 Backup dimulai...');
//   final allProducts = await products!.get();
//   final user = await getCurrentUsername();

//   for (var doc in allProducts.docs) {
//     final data = doc.data() as Map<String, dynamic>;
//     await addHistory(
//       data['name'] ?? 'Unknown',
//       'backup',
//       data['amount'] ?? 0,
//       data['sku'] ?? '',
//       data['category'] ?? '',
//       data['imageUrl'] ?? '',
//       user,
//     );
//   }
//   print('✅ Backup selesai');
// }



// // Ambil daftar backup (history docs)
// Future<List<String>> getBackupList() async {
//   final snapshot = await history!.get();
//   return snapshot.docs.map((doc) => doc.id).toList();
// }

// Future<void> restoreFromItemAdded() async {
//   try {
//     final firestore = FirebaseFirestore.instance;

//     // Ambil semua data history dengan action item_added
//     final historySnapshot = await firestore
//         .collection('history')
//         .where('action', isEqualTo: 'item_added')
//         .get();

//     if (historySnapshot.docs.isEmpty) {
//       print("⚠️ Tidak ada item dengan action 'item_added' di history");
//       return;
//     }

//     for (var doc in historySnapshot.docs) {
//       final data = doc.data();

//       final sku = data['item_sku'] ?? '';
//       final category = data['category'] ?? '';
//       final productName = data['item_name'] ?? 'Unknown';

//       if (sku.isEmpty || category.isEmpty) continue;

//       // Cek apakah sudah ada di subcollection
//       final itemRef = firestore
//           .collection('categories')
//           .doc(category)
//           .collection('items')
//           .doc(sku);

//       final existing = await itemRef.get();
//       if (existing.exists) {
//         print("⏩ SKU $sku ($productName) sudah ada, skip restore");
//         continue;
//       }

//       // Bangun data restore
//       final restoredData = {
//         'sku': sku,
//         'name': productName,
//         'merk': data['item_merk'] ?? '',
//         'amount': data['amount'] ?? 0,
//         'by': data['user_email'] ?? '',
//         'imageUrl': data['imageUrl'] ?? '', // optional kalau ada
//         'hasCustomImage': (data['imageUrl'] ?? '').isNotEmpty,
//         'last_updated': FieldValue.serverTimestamp(),
//         'timestamp': data['timestamp'],
//       };

//       // Simpan ke subcollection kategori/items
//       await itemRef.set(restoredData);

//       print("✅ Produk $productName ($sku) berhasil direstore ke kategori $category");
//     }
//   } catch (e) {
//     print("❌ Error saat restoreFromItemAdded: $e");
//   }
// }

}