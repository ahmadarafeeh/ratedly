import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/screens/post_view_screen.dart';
import 'package:Ratedly/utils/global_variable.dart';
import 'package:Ratedly/resources/profile_firestore_methods.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final userProvider = Provider.of<UserProvider>(context);

    if (userProvider.user == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFd9d9d9))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: width > webScreenSize
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF121212),
              toolbarHeight: 100, // Increase AppBar height
              automaticallyImplyLeading: false, // Remove default leading icon
              title: Align(
                alignment: Alignment.centerLeft, // Align logo to the left
                child: Image.asset(
                  'assets/logo/23.png',
                  width: 160, // Increased width
                  height: 120, // Increased height
                  fit: BoxFit.contain, // Maintain aspect ratio
                ),
              ),
              iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
            ),
      body: _NotificationList(currentUserId: userProvider.user!.uid),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final String currentUserId;

  const _NotificationList({required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFd9d9d9)));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: Text(
                'No notifications yet. Follow, rate posts, and comment.',
                style: TextStyle(color: Color(0xFFd9d9d9), fontSize: 16),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final notification =
                snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return _NotificationItem(
              notification: notification,
              currentUserId: currentUserId,
            );
          },
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String currentUserId;

  const _NotificationItem({
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    switch (notification['type']) {
      case 'comment':
        return _CommentNotification(notification: notification);
      case 'post_rating':
        return _PostRatingNotification(notification: notification);
      case 'user_rating':
        return _ProfileRatingNotification(notification: notification);
      case 'follow_request':
        return _FollowRequestNotification(
          notification: notification,
          currentUserId: currentUserId,
        );
      case 'follow_request_accepted':
        return _FollowAcceptedNotification(notification: notification);
      case 'comment_like':
        return _CommentLikeNotification(notification: notification);
      case 'follow':
        return _FollowNotification(notification: notification);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _FollowNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _FollowNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['followerId'],
      title: '${notification['followerUsername']} started following you',
      timestamp: notification['timestamp'],
      onTap: () => _navigateToProfile(context, notification['followerId']),
    );
  }
}

class _CommentNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _CommentNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['commenterUid'],
      title: '${notification['commenterName']} commented on your post',
      subtitle: notification['commentText'],
      timestamp: notification['timestamp'],
      onTap: () => _navigateToPost(context, notification['postId']),
    );
  }
}

class _PostRatingNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _PostRatingNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    final raterUserId = notification['raterUid'] as String? ?? '';
    final raterUsername = notification['raterUsername'] as String? ?? 'Someone';
    final rating = (notification['rating'] as num?)?.toDouble() ?? 0.0;

    return _NotificationTemplate(
      userId: raterUserId,
      title: '$raterUsername rated your post',
      subtitle: 'Rating: ${rating.toStringAsFixed(1)}',
      timestamp: notification['timestamp'],
      onTap: () => _navigateToProfile(context, raterUserId),
    );
  }
}

class _ProfileRatingNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _ProfileRatingNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    final raterUserId =
        notification['raterUserId'] as String? ?? 'invalid_user';
    final raterUsername = notification['raterUsername'] as String? ?? 'Someone';
    final rating = (notification['rating'] as num?)?.toDouble() ?? 0.0;

    return _NotificationTemplate(
      userId: raterUserId,
      title: '$raterUsername rated your profile',
      subtitle: 'Rating: ${rating.toStringAsFixed(1)}',
      timestamp: notification['timestamp'],
      onTap: raterUserId != 'invalid_user'
          ? () => _navigateToProfile(context, raterUserId)
          : null,
    );
  }
}

class _FollowRequestNotification extends StatelessWidget {
  final Map<String, dynamic> notification;
  final String currentUserId;

  const _FollowRequestNotification({
    required this.notification,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(notification['requesterId'])
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final user = snapshot.data!.data() as Map<String, dynamic>;
        return _NotificationTemplate(
          userId: notification['requesterId'],
          title: '${user['username']} wants to follow you',
          timestamp: notification['timestamp'],
          actions: [
            TextButton(
              onPressed: () => FireStoreProfileMethods().acceptFollowRequest(
                  currentUserId, notification['requesterId']),
              child: const Text('Accept',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
            ),
            TextButton(
              onPressed: () => FireStoreProfileMethods().declineFollowRequest(
                  currentUserId, notification['requesterId']),
              child: const Text('Decline',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
            ),
          ],
        );
      },
    );
  }
}

class _FollowAcceptedNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _FollowAcceptedNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['senderId'],
      title: '${notification['senderUsername']} approved your follow request',
      timestamp: notification['timestamp'],
      onTap: () => _navigateToProfile(context, notification['senderId']),
    );
  }
}

class _CommentLikeNotification extends StatelessWidget {
  final Map<String, dynamic> notification;

  const _CommentLikeNotification({required this.notification});

  @override
  Widget build(BuildContext context) {
    return _NotificationTemplate(
      userId: notification['likerUid'],
      title: '${notification['likerUsername']} liked your comment',
      subtitle: notification['commentText'],
      timestamp: notification['timestamp'],
      onTap: () => _navigateToPost(context, notification['postId']),
    );
  }
}

class _NotificationTemplate extends StatelessWidget {
  final String userId;
  final String title;
  final String? subtitle;
  final dynamic timestamp;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final bool showRatingBadge;

  const _NotificationTemplate({
    required this.userId,
    required this.title,
    this.subtitle,
    required this.timestamp,
    this.onTap,
    this.actions,
    this.showRatingBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF333333),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        leading: _UserAvatarWithRating(
            userId: userId, showRatingBadge: showRatingBadge),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFFd9d9d9))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null)
              Text(subtitle!, style: const TextStyle(color: Color(0xFF999999))),
            Text(_formatTimestamp(timestamp),
                style: const TextStyle(color: Color(0xFF999999))),
            if (actions != null) Row(children: actions!),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      return timeago.format((timestamp as Timestamp).toDate());
    } catch (e) {
      return 'Loading';
    }
  }
}

class _UserAvatarWithRating extends StatelessWidget {
  final String userId;
  final bool showRatingBadge;

  const _UserAvatarWithRating({
    required this.userId,
    this.showRatingBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final user = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final rating = _calculateAverageRating(user['ratings']);
        final profilePic = user['photoUrl']?.toString() ?? '';

        return SizedBox(
          width: 50,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: Colors.transparent,
                backgroundImage:
                    (profilePic.isNotEmpty && profilePic != "default")
                        ? NetworkImage(profilePic)
                        : null,
                child: (profilePic.isEmpty || profilePic == "default")
                    ? const Icon(
                        Icons.account_circle,
                        size: 42,
                        color: Color(0xFFd9d9d9),
                      )
                    : null,
              ),
              if (showRatingBadge)
                Positioned(
                  top: -12,
                  right: -8,
                  child: _RatingBadge(rating: rating),
                ),
            ],
          ),
        );
      },
    );
  }

  double _calculateAverageRating(List<dynamic>? ratings) {
    if (ratings == null || ratings.isEmpty) return 0.0;
    final total = ratings.fold<double>(
        0.0, (acc, r) => acc + (r['rating'] as num).toDouble());
    return total / ratings.length;
  }
}

class _RatingBadge extends StatelessWidget {
  final double rating;

  const _RatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        color: Color(0xFF333333),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 3,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Center(
        child: Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Color(0xFFd9d9d9),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

void _navigateToProfile(BuildContext context, String uid) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => ProfileScreen(uid: uid)),
  );
}

void _navigateToPost(BuildContext context, String postId) async {
  final postSnapshot =
      await FirebaseFirestore.instance.collection('posts').doc(postId).get();

  if (postSnapshot.exists) {
    final postData = postSnapshot.data() as Map<String, dynamic>;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewScreen(
          imageUrl: postData['postUrl'],
          postId: postId,
          description: postData['description'],
          userId: postData['uid'],
          username: postData['username'],
          profImage: postData['profImage'],
        ),
      ),
    );
  } else {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Post not found')));
  }
}
