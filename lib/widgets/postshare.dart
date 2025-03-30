import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/resources/messages_firestore_methods.dart';

class PostShare extends StatefulWidget {
  final String currentUserId;
  final String postId;

  const PostShare({
    Key? key,
    required this.currentUserId,
    required this.postId,
  }) : super(key: key);

  @override
  _PostShareState createState() => _PostShareState();
}

class _PostShareState extends State<PostShare> {
  List<String> selectedUsers = [];
  bool _isSharing = false;
  final _firestore = FirebaseFirestore.instance;

  Future<void> _sharePost() async {
    if (_isSharing || selectedUsers.isEmpty) return;

    setState(() => _isSharing = true);

    try {
      final postSnapshot =
          await _firestore.collection('posts').doc(widget.postId).get();

      if (!postSnapshot.exists) {
        throw Exception('Post does not exist');
      }

      final postData = postSnapshot.data() as Map<String, dynamic>;

      // Get post details with null checks
      final String postImageUrl = postData['postUrl'] ?? '';
      final String postCaption = postData['description'] ?? '';
      final String postOwnerId = postData['uid'] ?? '';
      final String postOwnerUsername = postData['username'] ?? 'Unknown User';
      final String postOwnerPhotoUrl = postData['profImage'] ?? '';

      // Share with each selected user
      for (String userId in selectedUsers) {
        try {
          final chatId = await FireStoreMessagesMethods()
              .getOrCreateChat(widget.currentUserId, userId);

          await FireStorePostsMethods().sharePostThroughChat(
            chatId: chatId,
            senderId: widget.currentUserId,
            receiverId: userId,
            postId: widget.postId,
            postImageUrl: postImageUrl,
            postCaption: postCaption,
            postOwnerId: postOwnerId,
            postOwnerUsername: postOwnerUsername,
            postOwnerPhotoUrl: postOwnerPhotoUrl,
          );
        } catch (e) {
          print('Error sharing with $userId: $e');
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Post shared with ${selectedUsers.length} user(s)'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing post: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share Post',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('chats')
                    .where('participants', arrayContains: widget.currentUserId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  return ListView.builder(
                    itemCount: snapshot.data!.docs.length,
                    itemBuilder: (context, index) {
                      final chat = snapshot.data!.docs[index];

                      // Safely extract participants with null check
                      final participants =
                          List<String>.from(chat['participants'] ?? []);

                      // Safely find the other user ID with fallback
                      final otherUserId = participants.firstWhere(
                        (userId) => userId != widget.currentUserId,
                        orElse: () => '', // Fallback to empty string
                      );

                      // Skip if no valid user ID is found
                      if (otherUserId.isEmpty) return const SizedBox.shrink();

                      return FutureBuilder<DocumentSnapshot>(
                        future: _firestore
                            .collection('users')
                            .doc(otherUserId)
                            .get(),
                        builder: (context, userSnapshot) {
                          // Handle loading state
                          if (userSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const ListTile(
                              title: Text('Loading...',
                                  style: TextStyle(color: Colors.black)),
                            );
                          }

                          // Handle missing or invalid user data
                          if (!userSnapshot.hasData ||
                              !userSnapshot.data!.exists) {
                            return const ListTile(
                              title: Text('User not found',
                                  style: TextStyle(color: Colors.black)),
                            );
                          }

                          // Safely cast user data with fallback
                          final userData = userSnapshot.data!.data()
                                  as Map<String, dynamic>? ??
                              {};

                          return ListTile(
                            leading: CircleAvatar(
                              radius: 21,
                              backgroundColor: Colors.transparent,
                              backgroundImage: (userData['photoUrl'] != null &&
                                      userData['photoUrl'].isNotEmpty &&
                                      userData['photoUrl'] != "default")
                                  ? NetworkImage(userData['photoUrl'])
                                  : null,
                              child: (userData['photoUrl'] == null ||
                                      userData['photoUrl'].isEmpty ||
                                      userData['photoUrl'] == "default")
                                  ? Icon(
                                      Icons.account_circle,
                                      size: 42,
                                      color: Colors.grey[600],
                                    )
                                  : null,
                            ),
                            title: Text(
                              userData['username'] ?? 'Unknown User',
                              style: const TextStyle(color: Colors.black),
                            ),
                            trailing: Checkbox(
                              value: selectedUsers.contains(otherUserId),
                              onChanged: _isSharing
                                  ? null
                                  : (bool? selected) {
                                      setState(() {
                                        if (selected == true) {
                                          selectedUsers.add(otherUserId);
                                        } else {
                                          selectedUsers.remove(otherUserId);
                                        }
                                      });
                                    },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _isSharing || selectedUsers.isEmpty ? null : _sharePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isSharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : const Text('Share Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
