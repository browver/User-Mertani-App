// import 'package:cloud_firestore/cloud_firestore.dart';

// import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreServices {
  final CollectionReference? components =
    FirebaseFirestore.instance.collection('components');
  final CollectionReference? sensors =
    FirebaseFirestore.instance.collection('sensors');
  final CollectionReference? loggers =
    FirebaseFirestore.instance.collection('loggers');

  // adding Component
  Future<void> addComponent(String component, int quantity, double price, String sku, String category) async{
    await components!.add({
      'component':component,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'category': category,
      
      'timestamp': FieldValue.serverTimestamp()}
      );

    // adding to history
    await addHistory(
      component,
      'add',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );    
  }

  // adding Sensor
   Future<void> addSensor(String sensor, int quantity, double price, String sku, String category) async{
    await sensors!.add({
      'sensor':sensor,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'category': category,
      
      'timestamp': FieldValue.serverTimestamp()}
      );

    // adding to history
    await addHistory(
      sensor,
      'add',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );    
  }

    // adding Logger
   Future<void> addLogger(String logger, int quantity, double price, String sku, String category) async{
    await loggers!.add({
      'logger':logger,
      'quantity': quantity,
      'price': price,
      'sku': sku,
      'category': category,
      
      'timestamp': FieldValue.serverTimestamp()}
      );

    // adding to history
    await addHistory(
      logger,
      'add',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );    
  } 

  //read data
  Stream<QuerySnapshot> showComponents() {
    final componentsStream = components!.orderBy('timestamp', descending: true).snapshots();
    return componentsStream;
  }

    //read data
  Stream<QuerySnapshot> showSensors() {
    final sensorsStream = sensors!.orderBy('timestamp', descending: true).snapshots();
    return sensorsStream;
  }

    //read data
  Stream<QuerySnapshot> showLoggers() {
    final loggersStream = loggers!.orderBy('timestamp', descending: true).snapshots();
    return loggersStream;
  }


  // update Component
  Future<void> updateComponents(String docId, String newComponent, int quantity, double price, String sku, String category,Timestamp time) async{
    await components!.doc(docId).update({
      'component':newComponent,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'category': category,
      'timestamp': time});

      await addHistory(
      newComponent,
      'update',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

  // update Sensor
  Future<void> updateSensors(String docId, String newSensor, int quantity, double price, String sku, String category,Timestamp time) async{
    await sensors!.doc(docId).update({
      'sensor':newSensor,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'category': category,
      'timestamp': time});

      await addHistory(
      newSensor,
      'update',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

    // update Logger
  Future<void> updateLoggers(String docId, String newLogger, int quantity, double price, String sku, String category,Timestamp time) async{
    await loggers!.doc(docId).update({
      'logger':newLogger,
      'quantity':quantity,
      'price':price,
      'sku': sku,
      'category': category,
      'timestamp': time});

      await addHistory(
      newLogger,
      'update',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

// delete Component
Future<void> deleteComponent(String docId) async {
  final docSnapshot = await components!.doc(docId).get();
  final data = docSnapshot.data() as Map<String, dynamic>?;

  if (data != null) {
    final component = data['components'] ?? '';
    final quantity = data['quantity'] ?? 0;
    final price = data['price'] ?? 0.0;
    final sku = data['sku'] ?? '';
    final category = data['category'] ?? '';


    await addHistory(
      component,
      'sold',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

  // delete all components
  await components!.doc(docId).delete();
}

// delete sensor
Future<void> deleteSensor(String docId) async {
  final docSnapshot = await sensors!.doc(docId).get();
  final data = docSnapshot.data() as Map<String, dynamic>?;

  if (data != null) {
    final sensor = data['sensor'] ?? '';
    final quantity = data['quantity'] ?? 0;
    final price = data['price'] ?? 0.0;
    final sku = data['sku'] ?? '';
    final category = data['category'] ?? '';


    await addHistory(
      sensor,
      'sold',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

  // delete all sensors
  await sensors!.doc(docId).delete();
}

// delete logger
Future<void> deleteLogger(String docId) async {
  final docSnapshot = await loggers!.doc(docId).get();
  final data = docSnapshot.data() as Map<String, dynamic>?;

  if (data != null) {
    final logger = data['logger'] ?? '';
    final quantity = data['quantity'] ?? 0;
    final price = data['price'] ?? 0.0;
    final sku = data['sku'] ?? '';
    final category = data['category'] ?? '';


    await addHistory(
      logger,
      'sold',
      quantity,
      sku,
      category,
      totalPrice: quantity * price,
    );
  }

  // delete all
  await loggers!.doc(docId).delete();
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