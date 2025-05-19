import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/screens/login.dart'; // Remove the alias
import 'package:Ratedly/screens/signup/age_screen.dart';
import 'package:Ratedly/screens/signup/verify_email_screen.dart';
import 'package:Ratedly/responsive/mobile_screen_layout.dart';
import 'package:Ratedly/responsive/web_screen_layout.dart';
import 'package:Ratedly/responsive/responsive_layout.dart';

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return const LoginScreen(); // Now correctly referenced

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const LoginScreen(); // Now correctly referenced
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        if (userData['onboardingComplete'] == true) {
          return const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          );
        }

        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        return const AgeVerificationScreen();
      },
    );
  }
}
