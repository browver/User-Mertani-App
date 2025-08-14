import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'category_page.dart';
import 'firebase_options.dart';
// import 'menu_dashboard.dart';
import 'login_page.dart';
import 'menu_dashboard.dart';
import 'user_interface.dart';
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
      title: 'Mertani Warehouse User',

      routes: {
        '/login': (context) => const LoginPage(),
        '/homepage': (context) => const MyHomePage(),
        '/category' : (context) => const CategoryPage(),
        '/userpage' : (context) => const UserPage()
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
