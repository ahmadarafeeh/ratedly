import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/screens/signup/auth_wrapper.dart';
import 'package:Ratedly/utils/colors.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase based on platform (web or mobile)
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyAFpbPiK6u8KMIfob0pu44ca8YLGYKJHDk",
        authDomain: "rateapp-3b78e.firebaseapp.com",
        projectId: "rateapp-3b78e",
        storageBucket: "rateapp-3b78e.firebasestorage.app",
        messagingSenderId: "411393947451",
        appId: "1:411393947451:web:62e5c1b57a3c7a66da691e",
        measurementId: "G-JSXVSH5PB8",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ratedly.',
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: mobileBackgroundColor,
          // Add these navigation bar theme properties
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: mobileBackgroundColor, // Match background
            selectedItemColor: primaryColor, // Your accent color
            unselectedItemColor: Colors.grey[600], // Inactive items
            selectedLabelStyle: const TextStyle(color: primaryColor),
            unselectedLabelStyle: TextStyle(color: Colors.grey[600]),
            type: BottomNavigationBarType.fixed,
            elevation: 0, // Remove shadow
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
