import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:helloworld/resources/storage_methods.dart';
import 'package:helloworld/resources/messages_firestore_methods.dart';

class FireStoreProfileMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FireStoreMessagesMethods _messagesMethods = FireStoreMessagesMethods();
  // Rate a user profile
  Future<String> rateUser(
      String targetUserId, String raterUserId, double rating) async {
    String res = "Some error occurred";
    try {
      double roundedRating = double.parse(rating.toStringAsFixed(1));
      // Fetch the target user document
      DocumentSnapshot userSnapshot =
          await _firestore.collection('users').doc(targetUserId).get();
      // Retrieve ratings field or default to an empty list.
      List<dynamic> ratings = userSnapshot['ratings'] ?? [];
      // Use client-side timestamp
      final timestamp = DateTime.now();
      // Check for an existing rating from this user
      bool hasRated =
          ratings.any((entry) => entry['raterUserId'] == raterUserId);
      if (hasRated) {
        // Update existing rating
        ratings = ratings.map((entry) {
          if (entry['raterUserId'] == raterUserId) {
            return {
              ...entry,
              'rating': roundedRating,
              'timestamp': timestamp, // Use client-side timestamp here.
            };
          }
          return entry;
        }).toList();
        await _firestore.collection('users').doc(targetUserId).update({
          'ratings': ratings,
        });
      } else {
        // Add new rating using arrayUnion, with client-side timestamp.
        await _firestore.collection('users').doc(targetUserId).update({
          'ratings': FieldValue.arrayUnion([
            {
              'raterUserId': raterUserId,
              'rating': roundedRating,
              'timestamp': timestamp,
            }
          ]),
        });
      }
      // Create or update notification for the rated user
      await _handleProfileRatingNotification(
          targetUserId, raterUserId, roundedRating);
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  // private or public account
  Future<void> toggleAccountPrivacy(String uid, bool isPrivate) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .update({'isPrivate': isPrivate});
  }

  // Handle profile rating notification creation or update
  Future<void> _handleProfileRatingNotification(
    String targetUserId,
    String raterUserId,
    double rating,
  ) async {
    try {
      final raterSnapshot =
          await _firestore.collection('users').doc(raterUserId).get();

      final notificationDocId = 'user_rating_${targetUserId}_$raterUserId';

      await _firestore.collection('notifications').doc(notificationDocId).set({
        'type': 'user_rating',
        'targetUserId': targetUserId,
        'raterUserId': raterUserId,
        'rating': rating,
        'raterUsername': raterSnapshot.get('username') ?? 'Anonymous',
        'raterProfilePic': raterSnapshot.get('photoUrl') ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      }, SetOptions(merge: true));
    } catch (err) {
      print('Error handling profile rating notification: $err');
    }
  }

// If private account is switched to public all follow requests are approved!
  Future<void> approveAllFollowRequests(String userId) async {
    final userRef = _firestore.collection('users').doc(userId);
    final batch = _firestore.batch();

    try {
      final userDoc = await userRef.get();
      final followRequests =
          (userDoc.data()?['followRequests'] as List? ?? []).toList();

      if (followRequests.isEmpty) return;

      // Process each follow request
      for (final request in followRequests) {
        final requesterId = request['userId'];
        final timestamp = request['timestamp'] ?? FieldValue.serverTimestamp();

        // 1. Add to user's followers
        batch.update(userRef, {
          'followers': FieldValue.arrayUnion([
            {'userId': requesterId, 'timestamp': timestamp}
          ])
        });

        // 2. Add to requester's following
        final requesterRef = _firestore.collection('users').doc(requesterId);
        batch.update(requesterRef, {
          'following': FieldValue.arrayUnion([
            {'userId': userId, 'timestamp': timestamp}
          ])
        });

        // 3. Delete follow request notification
        final notificationId = 'follow_request_${userId}_$requesterId';
        batch
            .delete(_firestore.collection('notifications').doc(notificationId));

        // 4. Create acceptance notification
        final userData = userDoc.data() as Map<String, dynamic>;
        final acceptNotificationId = 'follow_accept_${requesterId}_$userId';
        batch.set(
          _firestore.collection('notifications').doc(acceptNotificationId),
          {
            'type': 'follow_request_accepted',
            'targetUserId': requesterId,
            'senderId': userId,
            'senderUsername': userData['username'],
            'senderProfilePic': userData['photoUrl'],
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          },
        );
      }

      // 5. Clear all follow requests
      batch.update(userRef, {'followRequests': []});

      await batch.commit();
    } catch (e) {
      print('Error approving follow requests: $e');
      throw e;
    }
  }

// remove follower feature
  Future<void> removeFollower(String currentUserId, String followerId) async {
    try {
      final batch = _firestore.batch();
      final currentUserRef = _firestore.collection('users').doc(currentUserId);
      final followerRef = _firestore.collection('users').doc(followerId);

      // Remove follower from current user's followers
      final currentUserDoc = await currentUserRef.get();
      final followers = (currentUserDoc.data()?['followers'] as List?) ?? [];
      final followerEntry = followers.firstWhere(
        (entry) => entry['userId'] == followerId,
        orElse: () => null,
      );

      if (followerEntry != null) {
        batch.update(currentUserRef, {
          'followers': FieldValue.arrayRemove([followerEntry])
        });
      }

      // Remove current user from follower's following
      final followerDoc = await followerRef.get();
      final following = (followerDoc.data()?['following'] as List?) ?? [];
      final followingEntry = following.firstWhere(
        (entry) => entry['userId'] == currentUserId,
        orElse: () => null,
      );

      if (followingEntry != null) {
        batch.update(followerRef, {
          'following': FieldValue.arrayRemove([followingEntry])
        });
      }

      // Delete any related notifications
      final notificationsQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: followerId)
          .where('targetUserId', isEqualTo: currentUserId)
          .get();

      for (final doc in notificationsQuery.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error removing follower: $e');
      throw e;
    }
  }

  Future<void> unfollowUser(String uid, String unfollowId) async {
    try {
      final batch = _firestore.batch();
      final userRef = _firestore.collection('users').doc(uid);
      final targetUserRef = _firestore.collection('users').doc(unfollowId);

      // Remove from user's following
      final userDoc = await userRef.get();
      final following =
          (userDoc.data()! as Map<String, dynamic>)['following'] ?? [];
      final followingToRemove = following.firstWhere(
        (f) => f['userId'] == unfollowId,
        orElse: () => null,
      );

      if (followingToRemove != null) {
        batch.update(userRef, {
          'following': FieldValue.arrayRemove([followingToRemove])
        });
      }

      // Remove from target's followers and any residual requests
      final targetDoc = await targetUserRef.get();
      final followers =
          (targetDoc.data()! as Map<String, dynamic>)['followers'] ?? [];
      final followRequests =
          (targetDoc.data()! as Map<String, dynamic>)['followRequests'] ?? [];

      // Remove from followers
      final followerToRemove = followers.firstWhere(
        (f) => f['userId'] == uid,
        orElse: () => null,
      );

      if (followerToRemove != null) {
        batch.update(targetUserRef, {
          'followers': FieldValue.arrayRemove([followerToRemove])
        });
      }

      // Remove any residual follow requests
      final requestToRemove = followRequests.firstWhere(
        (r) => r['userId'] == uid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      // Delete follow notification
      final notificationQuery = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: uid)
          .where('targetUserId', isEqualTo: unfollowId)
          .limit(1)
          .get();

      if (notificationQuery.docs.isNotEmpty) {
        batch.delete(notificationQuery.docs.first.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error unfollowing user: $e');
      throw e;
    }
  }

  // Follow or unfollow a user with notification management
  Future<void> followUser(String uid, String followId) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);
      final targetUserRef = _firestore.collection('users').doc(followId);
      final timestamp = DateTime.now();

      final isPrivate = (await targetUserRef.get())['isPrivate'] ?? false;
      final hasPending = await hasPendingRequest(uid, followId);

      // Check if already following by querying the user's following list
      final currentUserDoc = await userRef.get();
      final following =
          (currentUserDoc.data()! as Map<String, dynamic>)['following'] ?? [];
      final isAlreadyFollowing =
          following.any((entry) => entry['userId'] == followId);

      if (hasPending || isAlreadyFollowing) {
        await declineFollowRequest(followId, uid);
        return;
      }

      if (isPrivate) {
        final requestData = {'userId': uid, 'timestamp': timestamp};
        await targetUserRef.update({
          'followRequests': FieldValue.arrayUnion([requestData])
        });
        await _createFollowRequestNotification(uid, followId);
      } else {
        final batch = _firestore.batch();

        final followerData = {'userId': uid, 'timestamp': timestamp};
        final followingData = {'userId': followId, 'timestamp': timestamp};

        batch.update(targetUserRef, {
          'followers': FieldValue.arrayUnion([followerData])
        });

        batch.update(userRef, {
          'following': FieldValue.arrayUnion([followingData])
        });

        await batch.commit();
        await createFollowNotification(uid, followId);
      }
    } catch (e) {
      print('Error following user: $e');
    }
  }

  // New: Follow request notification handler
  Future<void> _createFollowRequestNotification(
      String requesterUid, String targetUid) async {
    try {
      final notificationId = 'follow_request_${targetUid}_$requesterUid';
      final requesterSnapshot =
          await _firestore.collection('users').doc(requesterUid).get();

      await _firestore.collection('notifications').doc(notificationId).set({
        'type': 'follow_request',
        'targetUserId': targetUid,
        'requesterId': requesterUid,
        'requesterUsername': requesterSnapshot['username'],
        'requesterProfilePic': requesterSnapshot['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (err) {
      print('Error handling follow request notification: $err');
    }
  }

  // Updated acceptFollowRequest
  Future<void> acceptFollowRequest(
      String targetUid, String requesterUid) async {
    try {
      final batch = _firestore.batch();
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      final requesterRef = _firestore.collection('users').doc(requesterUid);
      final notificationRef = _firestore
          .collection('notifications')
          .doc('follow_request_${targetUid}_$requesterUid');

      // Fetch the exact follow request to remove
      final targetUserDoc = await targetUserRef.get();
      final followRequests =
          (targetUserDoc.data()?['followRequests'] as List?) ?? [];
      final requestToRemove = followRequests.firstWhere(
        (req) => req['userId'] == requesterUid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      final timestamp = DateTime.now();
      batch.update(targetUserRef, {
        'followers': FieldValue.arrayUnion([
          {'userId': requesterUid, 'timestamp': timestamp}
        ])
      });

      batch.update(requesterRef, {
        'following': FieldValue.arrayUnion([
          {'userId': targetUid, 'timestamp': timestamp}
        ])
      });

      batch.delete(notificationRef);
      await batch.commit();

      final targetUserSnapshot = await targetUserRef.get();
      final targetUsername = targetUserSnapshot['username'];
      final targetProfilePic = targetUserSnapshot['photoUrl'];

      await _createFollowRequestAcceptedNotification(
        targetUid: targetUid,
        requesterUid: requesterUid,
        targetUsername: targetUsername,
        targetProfilePic: targetProfilePic,
      );

      await createFollowNotification(requesterUid, targetUid);
    } catch (e) {
      print('Error accepting follow request: $e');
    }
  }

  Future<void> _createFollowRequestAcceptedNotification({
    required String targetUid,
    required String requesterUid,
    required String targetUsername,
    required String targetProfilePic,
  }) async {
    try {
      final notificationId = 'follow_accept_${requesterUid}_$targetUid';

      await _firestore.collection('notifications').doc(notificationId).set({
        'type': 'follow_request_accepted',
        'targetUserId': requesterUid, // Notification recipient
        'senderId': targetUid,
        'senderUsername': targetUsername,
        'senderProfilePic': targetProfilePic,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    } catch (err) {
      print('Error creating acceptance notification: $err');
    }
  }

  // Update declineFollowRequest
  Future<void> declineFollowRequest(
      String targetUid, String requesterUid) async {
    try {
      final batch = _firestore.batch();
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      final requesterRef = _firestore.collection('users').doc(requesterUid);

      // Get current follow requests to find exact object
      final targetUserDoc = await targetUserRef.get();
      final followRequests = targetUserDoc['followRequests'] ?? [];
      final requestToRemove = followRequests.firstWhere(
        (req) => req['userId'] == requesterUid,
        orElse: () => null,
      );

      if (requestToRemove != null) {
        batch.update(targetUserRef, {
          'followRequests': FieldValue.arrayRemove([requestToRemove])
        });
      }

      // Remove from requester's following if exists
      final requesterDoc = await requesterRef.get();
      final following = requesterDoc['following'] ?? [];
      final followingToRemove = following.firstWhere(
        (f) => f['userId'] == targetUid,
        orElse: () => null,
      );

      if (followingToRemove != null) {
        batch.update(requesterRef, {
          'following': FieldValue.arrayRemove([followingToRemove])
        });
      }

      // Delete notification
      final notificationRef = _firestore
          .collection('notifications')
          .doc('follow_request_${targetUid}_$requesterUid');
      batch.delete(notificationRef);

      await batch.commit();
    } catch (e) {
      print('Error declining follow request: $e');
    }
  }

  Future<String> reportProfile(String userId, String reason) async {
    String res = "Some error occurred";
    try {
      await _firestore.collection('reports').add({
        'userId': userId,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'profile',
      });
      res = 'success';
    } catch (err) {
      res = err.toString();
    }
    return res;
  }

  Future<bool> hasPendingRequest(String requesterUid, String targetUid) async {
    final targetUserDoc =
        await _firestore.collection('users').doc(targetUid).get();
    final followRequests = targetUserDoc['followRequests'] ?? [];
    return followRequests.any((req) => req['userId'] == requesterUid);
  }

// Create or update follow notification
  Future<void> createFollowNotification(
      String followerUid, String followedUid) async {
    try {
      final notificationsRef = _firestore.collection('notifications');
      // Create descriptive ID using both user IDs
      final notificationId = 'follow_${followedUid}_$followerUid';

      final followerSnapshot =
          await _firestore.collection('users').doc(followerUid).get();

      final notificationData = {
        'type': 'follow',
        'targetUserId': followedUid,
        'followerId': followerUid,
        'followerUsername': followerSnapshot['username'],
        'followerProfilePic': followerSnapshot['photoUrl'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      // Use set with merge to update existing or create new
      await notificationsRef
          .doc(notificationId)
          .set(notificationData, SetOptions(merge: true));

      print('Follow notification created/updated with ID: $notificationId');
    } catch (err) {
      print('Error handling follow notification: $err');
      // Consider rethrowing or error handling
    }
  }

// Update follow notification status
  Future<void> _updateFollowNotification(String followerUid, String followedUid,
      {required bool isRead}) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .where('type', isEqualTo: 'follow')
          .where('followerId', isEqualTo: followerUid)
          .where('targetUserId', isEqualTo: followedUid)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await _firestore
            .collection('notifications')
            .doc(query.docs.first.id)
            .update({'isRead': isRead});
      }
    } catch (e) {
      if (kDebugMode) print('Error updating follow notification: $e');
    }
  }

  Future<String> deleteEntireUserAccount(
      String uid, AuthCredential credential) async {
    String res = "Some error occurred";
    String? profilePicUrl;

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || currentUser.uid != uid) {
        throw Exception("User not authenticated or UID mismatch");
      }

      await currentUser.reauthenticateWithCredential(credential);
      DocumentSnapshot userSnap =
          await _firestore.collection('users').doc(uid).get();

      if (userSnap.exists) {
        Map<String, dynamic> data = userSnap.data() as Map<String, dynamic>;
        profilePicUrl = data['photoUrl'] as String?;
        WriteBatch batch = _firestore.batch();

        // Clean up followers/following relationships
        List<dynamic> followers = data['followers'] ?? [];
        List<dynamic> following = data['following'] ?? [];

        // Clean up followers' following lists
        for (var follower in followers) {
          if (follower['userId'] != null) {
            DocumentReference followerRef =
                _firestore.collection('users').doc(follower['userId']);
            batch.update(followerRef, {
              'following': FieldValue.arrayRemove([
                {'userId': uid, 'timestamp': follower['timestamp']}
              ])
            });
          }
        }

        // Clean up following's followers lists
        for (var followed in following) {
          if (followed['userId'] != null) {
            DocumentReference followedRef =
                _firestore.collection('users').doc(followed['userId']);
            batch.update(followedRef, {
              'followers': FieldValue.arrayRemove([
                {'userId': uid, 'timestamp': followed['timestamp']}
              ])
            });
          }
        }

        Future<void> _deletePostSubcollections(
            DocumentReference postRef) async {
          try {
            // Delete comments subcollection
            final comments = await postRef.collection('comments').get();
            for (DocumentSnapshot comment in comments.docs) {
              await comment.reference.delete();
            }

            // Delete views subcollection
            final views = await postRef.collection('views').get();
            for (DocumentSnapshot view in views.docs) {
              await view.reference.delete();
            }
          } catch (e) {
            print('Error deleting post subcollections: $e');
          }
        }

        await _deleteAllUserChatsAndMessages(uid, batch); // Add this line
        // Delete user's posts and their storage
        QuerySnapshot postsSnap = await _firestore
            .collection('posts')
            .where('uid', isEqualTo: uid)
            .get();

// Delete in chunks to avoid batch limits
        const batchSize = 400;
        for (int i = 0; i < postsSnap.docs.length; i += batchSize) {
          WriteBatch postBatch = _firestore.batch();
          final postsChunk = postsSnap.docs.sublist(
              i,
              i + batchSize > postsSnap.docs.length
                  ? postsSnap.docs.length
                  : i + batchSize);

          for (DocumentSnapshot doc in postsChunk) {
            // 1. Delete post document
            postBatch.delete(doc.reference);

            // 2. Delete image from storage
            await StorageMethods().deleteImage(doc['postUrl']);

            // 3. Delete post subcollections (comments, views)
            await _deletePostSubcollections(doc.reference);
          }

          await postBatch.commit();
        }
        // Delete all comments by the user
        QuerySnapshot commentsSnap = await _firestore
            .collectionGroup('comments')
            .where('uid', isEqualTo: uid)
            .get();
        for (DocumentSnapshot commentDoc in commentsSnap.docs) {
          batch.delete(commentDoc.reference);
        }

        // Remove user's ratings from all posts
        QuerySnapshot allPosts = await _firestore.collection('posts').get();
        for (DocumentSnapshot postDoc in allPosts.docs) {
          List<dynamic> ratings = postDoc['rate'] as List? ?? [];
          List<dynamic> updatedRatings =
              ratings.where((rating) => rating['userId'] != uid).toList();
          if (updatedRatings.length < ratings.length) {
            batch.update(postDoc.reference, {'rate': updatedRatings});
          }
        }

        // Remove user's profile ratings from other users
        QuerySnapshot allUsers = await _firestore.collection('users').get();
        for (DocumentSnapshot userDoc in allUsers.docs) {
          if (userDoc.id == uid) continue;
          List<dynamic> ratings = userDoc['ratings'] as List? ?? [];
          List<dynamic> updatedRatings =
              ratings.where((rating) => rating['raterUserId'] != uid).toList();
          if (updatedRatings.length < ratings.length) {
            batch.update(userDoc.reference, {'ratings': updatedRatings});
          }
        }

        // Delete user document
        DocumentReference userDocRef = _firestore.collection('users').doc(uid);
        batch.delete(userDocRef);

        await batch.commit();

        // Delete all notifications
        Query notificationsQuery =
            _firestore.collection('notifications').where(Filter.or(
                  Filter('targetUserId', isEqualTo: uid),
                  Filter('senderId', isEqualTo: uid),
                  Filter('followerId', isEqualTo: uid),
                  Filter('raterUserId', isEqualTo: uid),
                  Filter('raterUid', isEqualTo: uid),
                  Filter('likerUid', isEqualTo: uid),
                  Filter('commenterUid', isEqualTo: uid),
                  Filter('requesterId', isEqualTo: uid),
                ));

        QuerySnapshot notifSnap = await notificationsQuery.get();
        while (notifSnap.docs.isNotEmpty) {
          WriteBatch notifBatch = _firestore.batch();
          for (DocumentSnapshot doc in notifSnap.docs) {
            notifBatch.delete(doc.reference);
          }
          await notifBatch.commit();
          notifSnap = await notificationsQuery
              .startAfterDocument(notifSnap.docs.last)
              .get();
        }

        // Delete profile image
        if (profilePicUrl != null &&
            profilePicUrl.isNotEmpty &&
            profilePicUrl != 'default') {
          // ← Add this validation
          await StorageMethods().deleteImage(profilePicUrl);
        }

        await currentUser.delete();
        res = "success";
      }
    } on FirebaseAuthException catch (e) {
      res = e.code == 'requires-recent-login'
          ? "Re-authentication required. Please sign in again."
          : e.message ?? "Authentication error";
    } catch (e) {
      res = e.toString();
    }
    return res;
  }

// Helper function to remove follow relationships with timestamps
  void _removeFollowRelationships({
    required DocumentSnapshot currentUserSnap,
    required DocumentSnapshot targetUserSnap,
    required String currentUserId,
    required String targetUid, // Fixed parameter name
    required WriteBatch batch,
  }) {
    // Remove target user from current user's following
    final followingList = (currentUserSnap['following'] as List?) ?? [];
    final targetFollowEntry = followingList.firstWhere(
      (entry) => entry['userId'] == targetUid, // Fixed reference
      orElse: () => null,
    );

    // Remove current user from target user's followers
    final followersList = (targetUserSnap['followers'] as List?) ?? [];
    final currentUserFollowerEntry = followersList.firstWhere(
      (entry) => entry['userId'] == currentUserId,
      orElse: () => null,
    );
  }

  Future<void> _deleteAllUserChatsAndMessages(
      String uid, WriteBatch batch) async {
    try {
      // Use existing participants index
      final chatsQuery = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();

      for (final chatDoc in chatsQuery.docs) {
        // Delete messages using existing timestamp index
        final messages = await chatDoc.reference
            .collection('messages')
            .orderBy('timestamp')
            .get();

        for (final messageDoc in messages.docs) {
          batch.delete(messageDoc.reference);
        }
        batch.delete(chatDoc.reference);
      }
    } catch (e) {
      print('Error deleting chats: $e');
      throw e;
    }
  }
}
