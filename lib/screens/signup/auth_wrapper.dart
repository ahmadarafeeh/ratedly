import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/responsive/mobile_screen_layout.dart';
import 'package:Ratedly/responsive/responsive_layout.dart';
import 'package:Ratedly/responsive/web_screen_layout.dart';
import 'package:Ratedly/screens/first_time/get_started_page.dart';
import 'package:Ratedly/screens/signup/onboarding_flow.dart';
import 'package:Ratedly/screens/signup/verify_email_screen.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Handle loading state
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle errors
        if (authSnapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Auth error: ${authSnapshot.error}')),
          );
        }

        // No user logged in
        final user = authSnapshot.data;
        if (user == null) return const GetStartedPage();

        // User exists but email not verified
        if (!user.emailVerified) {
          return const VerifyEmailScreen();
        }

        // Email verified - check Firestore document
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder: (context, userSnapshot) {
            // Handle loading state
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle errors
            if (userSnapshot.hasError) {
              return Scaffold(
                body: Center(
                    child: Text('Firestore error: ${userSnapshot.error}')),
              );
            }

            // Document doesn't exist - go to onboarding
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const OnboardingFlow();
            }

            // Initialize user provider
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              userProvider.refreshUser();
            });

            // Check onboarding completion
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final onboardingComplete = userData['onboardingComplete'] ?? false;

            return onboardingComplete
                ? const ResponsiveLayout(
                    mobileScreenLayout: MobileScreenLayout(),
                    webScreenLayout: WebScreenLayout(),
                  )
                : const OnboardingFlow();
          },
        );
      },
    );
  }
}
