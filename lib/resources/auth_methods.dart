import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helloworld/models/user.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:helloworld/resources/storage_methods.dart';

class AuthMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<AppUser> getUserDetails() async {
    // Changed return type to AppUser
    firebase_auth.User currentUser =
        _auth.currentUser!; // Explicit Firebase User
    DocumentSnapshot documentSnapshot =
        await _firestore.collection('users').doc(currentUser.uid).get();

    if (!documentSnapshot.exists) {
      throw Exception('User document not found');
    }

    return AppUser.fromSnap(documentSnapshot);
  }

  Future<String> signUpUser({
    required String email,
    required String password,
  }) async {
    try {
      if (email.isEmpty || password.isEmpty) {
        return "Please fill all required fields";
      }

      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user exists after creation
      if (cred.user == null) {
        return "Registration failed - please try again";
      }

      await cred.user!.sendEmailVerification();
      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Registration failed";
    } catch (err) {
      return err.toString();
    }
  }

// Updated completeProfile method to include email
// AuthMethods.dart
  Future<String> completeProfile({
    required String username,
    required String bio,
    Uint8List? file,
    required bool isPrivate,
    required String region,
    required int age,
    required String gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return "User not authenticated";

      await user.reload();
      if (!user.emailVerified) return "Email not verified";

      // Process and validate username
      final processedUsername = username.trim().toLowerCase();
      if (processedUsername.isEmpty) {
        return "Username cannot be empty";
      }

      // Validate username format
      if (!RegExp(r'^[a-z0-9_]+$').hasMatch(processedUsername)) {
        return "Username can only contain lowercase letters, numbers, and underscores";
      }

      // Check username uniqueness
      final usernameQuery = await _firestore
          .collection("users")
          .where("username", isEqualTo: processedUsername)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        return "Username already exists";
      }

      if (bio.isEmpty) {
        return "Please fill all required fields";
      }

      String photoUrl = 'default';
      if (file != null) {
        photoUrl = await StorageMethods()
            .uploadImageToStorage('profilePics', file, false);
      }

      // Create Firestore document with processed username
      await _firestore.collection("users").doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': processedUsername, // Store lowercase version
        'bio': bio,
        'photoUrl': photoUrl,
        'isPrivate': isPrivate,
        'followers': [],
        'following': [],
        'followRequests': [],
        'ratings': [],
        'onboardingComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'region': region,
        'age': age,
        'gender': gender,
      });

      return "success";
    } on FirebaseException catch (e) {
      return e.message ?? "Profile completion failed";
    } catch (err) {
      return err.toString();
    }
  }

  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if Firestore document exists
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(cred.user!.uid).get();

      if (!userDoc.exists) {
        return "onboarding_required"; // Redirect to profile setup
      }

      return "success";
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Login failed";
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
