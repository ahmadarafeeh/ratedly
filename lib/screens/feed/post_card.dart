import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:Ratedly/models/user.dart' as model;
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/screens/comment_screen.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/rating_section.dart';
import 'package:Ratedly/widgets/postshare.dart';
import 'package:provider/provider.dart';
import 'package:Ratedly/widgets/rating_list_screen.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';
import 'package:Ratedly/widgets/blocked_content_message.dart';

class PostCard extends StatefulWidget {
  final snap;
  final VoidCallback onRateUpdate;

  const PostCard({
    Key? key,
    required this.snap,
    required this.onRateUpdate,
  }) : super(key: key);

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int commentLen = 0;
  bool _viewRecorded = false;

  bool _isMounted = false; // Add mounted flag


  final List<String> reportReasons = [
    'I just don’t like it',
    'Discriminatory content (e.g., religion, race, gender, or other)',
    'Bullying or harassment',
    'Violence, hate speech, or harmful content',
    'Selling prohibited items',
    'Pornography or nudity',
    'Scam or fraudulent activity',
    'Spam',
    'Misinformation',
  ];

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    fetchCommentLen();
    _recordView();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }


  void _recordView() async {
    final user = Provider.of<UserProvider>(context, listen: false).user;
    if (user != null && !_viewRecorded) {
      await FireStorePostsMethods().recordPostView(
        widget.snap['postId'].toString(),
        user.uid,
      );
      if (_isMounted) { // Add mounted check
        setState(() => _viewRecorded = true);
      }
    }
  }

  fetchCommentLen() async {
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.snap['postId'])
          .collection('comments')
          .get();

      if (_isMounted) { // Add mounted check
        setState(() {
          commentLen = snap.docs.length;
        });
      }
    } catch (err) {
      if (_isMounted) {
        showSnackBar(context, err.toString());
      }
    }
  }

  // Add mounted check to deletePost
  deletePost(String postId) async {
    try {
      await FireStorePostsMethods().deletePost(postId);
      if (_isMounted) {
        showSnackBar(context, 'Post deleted successfully');
      }
    } catch (err) {
      if (_isMounted) {
        showSnackBar(context, err.toString());
      }
    }
  }


  void _showReportDialog(BuildContext context) {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF121212),
              title: const Text('Report Post',
                  style: TextStyle(color: Color(0xFFd9d9d9))),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thank you for helping keep our community safe.\n\nPlease let us know the reason for reporting this content. Your report is anonymous, and our moderators will review it as soon as possible. \n\n If you prefer not to see this user posts or content, you can choose to block them.',
                      style: TextStyle(color: Color(0xFFd9d9d9), fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Select a reason: \n',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFd9d9d9),
                      ),
                    ),
                    ...reportReasons.map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason,
                            style: const TextStyle(color: Color(0xFFd9d9d9))),
                        value: reason,
                        groupValue: selectedReason,
                        activeColor: const Color(0xFFd9d9d9),
                        onChanged: (value) {
                          setState(() => selectedReason = value);
                        },
                      );
                    }).toList(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: Color(0xFFd9d9d9))),
                ),
                TextButton(
                  onPressed: selectedReason != null
                      ? () {
                    FireStorePostsMethods()
                        .reportPost(
                      widget.snap['postId'].toString(),
                      selectedReason!,
                    )
                        .then((res) {
                      Navigator.pop(context);
                      if (res == 'success') {
                        showSnackBar(
                            context, 'Report submitted. Thank you!');
                      } else {
                        showSnackBar(
                            context, 'Failed to submit report: $res');
                      }
                    });
                  }
                      : null,
                  child: const Text('Submit',
                      style: TextStyle(color: Color(0xFFd9d9d9))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final model.AppUser? user = Provider.of<UserProvider>(context).user;
    if (user == null) return const Center(child: CircularProgressIndicator());

    return FutureBuilder<bool>(
      future: FirestoreBlockMethods().isMutuallyBlocked(
        user.uid,
        widget.snap['uid'],
      ),
      builder: (context, snapshot) {
        // Add error boundary
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading post',
                style: TextStyle(color: Color(0xFFd9d9d9))),
          );
        }        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(
              child: Text('Error checking block status',
                  style: TextStyle(color: Color(0xFFd9d9d9))));
        }
        if (snapshot.hasData && snapshot.data!) {
          return const BlockedContentMessage(
            message: 'Post unavailable due to blocking',
          );
        }

        final ratings = widget.snap['rate'] ?? [];
        final numOfRatings = ratings.length;
        final totalRating = ratings.fold<double>(0.0, (double acc, dynamic rating) {
          final value = rating['rating'];
          return acc + (value is num ? value.toDouble() : 0.0);
        });
        final averageRating = numOfRatings > 0 ? totalRating / numOfRatings : 0.0;

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF333333)),
            color: const Color(0xFF121212),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16)
                    .copyWith(right: 0),
                child: Row(
                  children: <Widget>[
                    FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(widget.snap['uid'])
                          .get(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircleAvatar(
                              radius: 22,
                              backgroundColor: Color(0xFF333333)
                          );
                        }
                        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                        // Calculate user's average rating from their 'ratings' field
                        final userRatings = (userData['ratings'] as List<dynamic>?) ?? [];
                        final userTotalRating = userRatings.fold<double>(
                            0.0,
                                (sum, rating) => sum + (rating['rating'] as double? ?? 0.0)
                        );
                        final userAverageRating = userRatings.isNotEmpty
                            ? userTotalRating / userRatings.length
                            : 0.0;

                        return SizedBox(
                          width: 50,
                          height: 50,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ProfileScreen(uid: widget.snap['uid']),
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 21,
                                  backgroundColor: const Color(0xFF333333),
                                  backgroundImage:
                                  (userData['photoUrl'] != null &&
                                      userData['photoUrl'].isNotEmpty &&
                                      userData['photoUrl'] != "default")
                                      ? NetworkImage(userData['photoUrl'])
                                      : null,
                                  child: (userData['photoUrl'] == null ||
                                      userData['photoUrl'].isEmpty ||
                                      userData['photoUrl'] == "default")
                                      ? Icon(Icons.account_circle,
                                      size: 42, color: Colors.grey[600])
                                      : null,
                                ),
                              ),
                              Positioned(
                                top: -8,
                                right: -8,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF333333),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                    BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 5,
                                    offset: Offset(0, 2)
                                    ) ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      userAverageRating.toStringAsFixed(1), // Use user's average here
                                      style: const TextStyle(
                                        color: Color(0xFFd9d9d9),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ProfileScreen(uid: widget.snap['uid']),
                                ),
                              ),
                              child: Text(
                                widget.snap['username'].toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFd9d9d9),
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => widget.snap['uid'].toString() == user.uid
                          ? showDialog(
                        context: context,
                        builder: (context) => Dialog(
                          backgroundColor: const Color(0xFF121212),
                          child: ListView(
                            padding:
                            const EdgeInsets.symmetric(vertical: 16),
                            shrinkWrap: true,
                            children: [
                              InkWell(
                                onTap: () {
                                  deletePost(
                                      widget.snap['postId'].toString());
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 16),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(
                                        color: Color(0xFFd9d9d9)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                          : _showReportDialog(context),
                      icon:
                      const Icon(Icons.more_vert, color: Color(0xFFd9d9d9)),
                    ),
                  ],
                ),
              ),

              // Image Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.network(
                    widget.snap['postUrl'].toString(),
                    fit: BoxFit.fitWidth,
                    width: double.infinity,
                  ),
                  if (widget.snap['description'] != null &&
                      widget.snap['description'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      child: Text(
                        widget.snap['description'].toString(),
                        style: const TextStyle(
                          color: Color(0xFFd9d9d9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                ],
              ),

              // Rating Section
              RatingSection(
                postId: widget.snap['postId'],
                userId: user.uid,
                ratings: ratings,
                onRateUpdate: widget.onRateUpdate,
              ),

              // Bottom Action Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.comment_outlined,
                              color: Color(0xFFd9d9d9)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommentsScreen(
                                postId: widget.snap['postId'].toString(),
                              ),
                            ),
                          ),
                        ),
                        if (commentLen > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF333333),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                commentLen.toString(),
                                style: const TextStyle(
                                  color: Color(0xFFd9d9d9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Color(0xFFd9d9d9)),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => PostShare(
                          currentUserId: FirebaseAuth.instance.currentUser!.uid,
                          postId: widget.snap['postId'],
                        ),
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                RatingListScreen(postId: widget.snap['postId']),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Text(
                          'Rated ${averageRating.toStringAsFixed(1)} by $numOfRatings voters',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFd9d9d9),
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}