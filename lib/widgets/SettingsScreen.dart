import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helloworld/resources/auth_methods.dart';
import 'package:helloworld/resources/profile_firestore_methods.dart';
import 'package:helloworld/screens/login.dart';
import 'package:helloworld/screens/Profile_page/blocked_profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;
  bool _isPrivate = false;
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);
  final Color _iconColor = const Color(0xFFd9d9d9);

  @override
  void initState() {
    super.initState();
    _loadPrivacyStatus();
  }

  Future<void> _loadPrivacyStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .get();
    setState(() => _isPrivate = doc['isPrivate'] ?? false);
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Update privacy status
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'isPrivate': value});

      // If switching to public, approve all pending requests
      if (!value) {
        await FireStoreProfileMethods().approveAllFollowRequests(currentUserId);
      }

      setState(() => _isPrivate = value);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating privacy: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  // Change Password method
  Future<void> _changePassword() async {
    TextEditingController currentPasswordController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    bool? confirmed = await showDialog(
      context: context,
      builder: (context) {
        String? errorMessage;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text(
                'Change Password',
                style: TextStyle(color: Colors.black),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null)
                    Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  TextField(
                    controller: currentPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current Password',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                      labelStyle: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.black)),
                ),
                TextButton(
                  onPressed: () {
                    if (newPasswordController.text !=
                        confirmPasswordController.text) {
                      setState(
                          () => errorMessage = 'New passwords do not match');
                      return;
                    }
                    if (newPasswordController.text.isEmpty) {
                      setState(
                          () => errorMessage = 'New password cannot be empty');
                      return;
                    }
                    if (currentPasswordController.text.isEmpty) {
                      setState(
                          () => errorMessage = 'Current password is required');
                      return;
                    }
                    Navigator.pop(context, true);
                  },
                  child: const Text('Change Password',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Reauthenticate with current password
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPasswordController.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);

      // Update to new password
      await user.updatePassword(newPasswordController.text.trim());

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password changed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error changing password: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Sign Out method
  Future<void> _signOut() async {
    await AuthMethods().signOut();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  // Delete Account method
  Future<void> _deleteAccount() async {
    // Confirmation dialog
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Delete Account',
          style: TextStyle(color: Colors.black),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (!confirmed) return;

    // Collect user password for reauthentication
    TextEditingController passwordController = TextEditingController();
    bool? confirmedPassword = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Password',
            style: TextStyle(color: Colors.black)),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.black),
          decoration: const InputDecoration(
            labelText: 'Enter your password to confirm deletion',
            labelStyle: TextStyle(color: Colors.black54),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black38),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[300],
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmedPassword != true) return;

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      String uid = user!.uid;
      String email = user.email!;

      // Create AuthCredential from email/password
      AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: passwordController.text.trim(),
      );

      // Call the deletion method from FireStoreMethods
      String res = await FireStoreProfileMethods()
          .deleteEntireUserAccount(uid, credential);

      if (res == "success") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted successfully')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $res')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting account: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  // Helper to build a settings option tile
  Widget _buildOptionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor ?? _iconColor),
        title: Text(title, style: TextStyle(color: _textColor)),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: _textColor)),
        centerTitle: true,
        backgroundColor: _backgroundColor,
        elevation: 1,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _textColor))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildOptionTile(
                    title: 'Private Account',
                    icon: Icons.lock,
                    onTap: () {},
                    trailing: Switch(
                      value: _isPrivate,
                      onChanged: _togglePrivacy,
                      activeColor: _textColor,
                    ),
                  ),
                  _buildOptionTile(
                    title: 'Blocked Users',
                    icon: Icons.block,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BlockedUsersList(
                          uid: FirebaseAuth.instance.currentUser!.uid,
                        ),
                      ),
                    ),
                  ),
                  _buildOptionTile(
                    title: 'Change Password',
                    icon: Icons.lock,
                    onTap: _changePassword,
                  ),
                  _buildOptionTile(
                    title: 'Sign Out',
                    icon: Icons.logout,
                    onTap: _signOut,
                  ),
                  _buildOptionTile(
                    title: 'Delete Account',
                    icon: Icons.delete,
                    iconColor: Colors.red[400],
                    onTap: _deleteAccount,
                  ),
                ],
              ),
            ),
    );
  }
}

class BlockedUsersList extends StatefulWidget {
  final String uid;
  const BlockedUsersList({Key? key, required this.uid}) : super(key: key);

  @override
  State<BlockedUsersList> createState() => _BlockedUsersListState();
}

class _BlockedUsersListState extends State<BlockedUsersList> {
  final Color _textColor = const Color(0xFFd9d9d9);
  final Color _backgroundColor = const Color(0xFF121212);
  final Color _cardColor = const Color(0xFF333333);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Blocked Users', style: TextStyle(color: _textColor)),
        backgroundColor: _backgroundColor,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _textColor));
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child:
                  Text('No blocked users', style: TextStyle(color: _textColor)),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final blockedUsers = List<String>.from(data['blockedUsers'] ?? []);

          if (blockedUsers.isEmpty) {
            return Center(
              child:
                  Text('No blocked users', style: TextStyle(color: _textColor)),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: blockedUsers.length,
            separatorBuilder: (context, index) =>
                Divider(color: _cardColor, height: 20),
            itemBuilder: (context, index) {
              final blockedUserId = blockedUsers[index];
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(blockedUserId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox.shrink();
                  }

                  final userData =
                      userSnapshot.data!.data() as Map<String, dynamic>?;
                  final username = userData?['username'] ?? 'Unknown User';
                  final photoUrl = userData?['photoUrl'] ?? '';

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: _cardColor,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Icon(Icons.person, color: _textColor)
                          : null,
                    ),
                    title: Text(
                      username,
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(Icons.lock_outline, color: _textColor),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlockedProfileScreen(
                            uid: blockedUserId,
                            isBlocker: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
