import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_application_2/category_page.dart';
import 'package:flutter_application_2/firebase_options.dart';
// import 'package:flutter_application_2/menu_dashboard.dart';
import 'package:flutter_application_2/login_page.dart';
import 'package:flutter_application_2/menu_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'homepage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mertani Warehouse',

      routes: {
        '/login': (context) => const LoginPage(),
        '/homepage': (context) => const MyHomePage(),
        '/category' : (context) => const CategoryPage(),
      },


      home: FutureBuilder <bool>(
        future: checkLoginStatus(),
         builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else {
            if (snapshot.data == true) {
              return const MyHomePage();
            } else {
              return const LoginPage();
            }
          }
         },
        ),
      // theme: ThemeData(
      //   colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      // ),
      // home: const LoginPage(),
    );
  }
}
