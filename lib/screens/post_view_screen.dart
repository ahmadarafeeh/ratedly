import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:Ratedly/models/user.dart' as model;
import 'package:Ratedly/providers/user_provider.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/screens/comment_screen.dart';
import 'package:Ratedly/screens/Profile_page/profile_page.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/flutter_rating_bar.dart';
import 'package:provider/provider.dart';
import 'package:Ratedly/widgets/postshare.dart';
import 'package:Ratedly/widgets/rating_list_screen.dart';
import 'package:Ratedly/resources/block_firestore_methods.dart';
import 'package:Ratedly/widgets/blocked_content_message.dart';

class ImageViewScreen extends StatefulWidget {
  final String imageUrl;
  final String postId;
  final String description;
  final String userId;
  final String username;
  final String profImage;

  const ImageViewScreen({
    Key? key,
    required this.imageUrl,
    required this.postId,
    required this.description,
    required this.userId,
    required this.username,
    required this.profImage,
  }) : super(key: key);

  @override
  State<ImageViewScreen> createState() => _ImageViewScreenState();
}

class _ImageViewScreenState extends State<ImageViewScreen> {
  int commentLen = 0;
  double currentRating = 0;
  bool userHasRated = false;
  final List<String> reportReasons = [
    'I just don’t like it',
    'Discriminatory content (e.g., religion, race, sexual orientation, gender, or other)',
    'Bullying or harassment',
    'Violence, hate speech, or harmful content',
    'Selling restricted or prohibited items',
    'Pornography or nudity',
    'Scam or fraudulent activity',
    'Spam',
    'Misinformation',
  ];

  @override
  void initState() {
    super.initState();
    fetchCommentLen();
    fetchUserRating();
  }

  fetchCommentLen() async {
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .get();
      commentLen = snap.docs.length;
    } catch (err) {
      if (mounted) {
        showSnackBar(context, err.toString());
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  fetchUserRating() async {
    try {
      DocumentSnapshot postSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .get();

      List rates = postSnapshot['rate'] ?? [];
      var userRating = rates.firstWhere(
            (rate) => rate['userId'] == widget.userId,
        orElse: () => null,
      );

      if (userRating != null) {
        if (mounted) {
          setState(() {
            currentRating = (userRating['rating'] as num).toDouble();
            userHasRated = true;
          });
        }
      }
    } catch (err) {
      if (mounted) {
        showSnackBar(context, err.toString());
      }
    }
  }

  deletePost(String postId) async {
    try {
      await FireStorePostsMethods().deletePost(postId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (err) {
      if (mounted) {
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
                      widget.postId,
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
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<bool>(
      future: FirestoreBlockMethods().isMutuallyBlocked(
        user.uid,
        widget.userId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
              body: Center(
                child: Text('Error checking block status',
                    style: TextStyle(color: Color(0xFFd9d9d9))),
              ));
        }
        if (snapshot.hasData && snapshot.data!) {
          return Scaffold(
            appBar: AppBar(),
            body: const BlockedContentMessage(
              message: 'Post unavailable due to blocking',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            iconTheme: const IconThemeData(color: Color(0xFFd9d9d9)),
            backgroundColor: const Color(0xFF121212),
            title: Text(
              widget.username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFd9d9d9),
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFd9d9d9)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Color(0xFFd9d9d9)),
                onPressed: () {
                  if (FirebaseAuth.instance.currentUser?.uid == widget.userId) {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: const Color(0xFF121212),
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shrinkWrap: true,
                          children: [
                            InkWell(
                              onTap: () {
                                deletePost(widget.postId);
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 16),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Color(0xFFd9d9d9)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    _showReportDialog(context);
                  }
                },
              ),
            ],
          ),
          backgroundColor: const Color(0xFF121212),
          body: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 16)
                      .copyWith(right: 0),
                  child: Row(
                    children: <Widget>[
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const CircleAvatar(
                                radius: 22, backgroundColor: Color(0xFF333333));
                          }

                          final userData =
                              snapshot.data?.data() as Map<String, dynamic>? ??
                                  {};
                          final ratings =
                              (userData['ratings'] as List<dynamic>?) ?? [];
                          double totalRating = ratings.fold<double>(
                            0.0,
                                (double total, dynamic rating) => total + (rating['rating'] as num).toDouble(),
                          );
                          final averageRating = ratings.isNotEmpty
                              ? totalRating / ratings.length
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
                                      builder: (context) =>
                                          ProfileScreen(uid: widget.userId),
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 21,
                                    backgroundColor: const Color(0xFF333333),
                                    backgroundImage: (userData['photoUrl'] !=
                                        null &&
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
                                            offset: Offset(0, 2))
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        averageRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Color(0xFFd9d9d9),
                                          fontSize: 11,
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
                          padding: const EdgeInsets.only(left: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProfileScreen(
                                        uid: widget.userId,
                                      ),
                                    ),
                                  );
                                },
                                child: Text(
                                  widget.username,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFd9d9d9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.fitWidth,
                  width: double.infinity,
                ),
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.description,
                      style: const TextStyle(
                        color: Color(0xFFd9d9d9),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.postId)
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator(
                            color: Color(0xFFd9d9d9));
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}',
                            style: const TextStyle(color: Color(0xFFd9d9d9)));
                      }

                      if (!snapshot.hasData || snapshot.data == null) {
                        return const Text('No data available',
                            style: TextStyle(color: Color(0xFFd9d9d9)));
                      }

                      var post = snapshot.data!.data() as Map<String, dynamic>;
                      List<dynamic> ratings =
                      post.containsKey('rate') ? post['rate'] : [];
                      int numOfRatings = ratings.length;
                      final totalRating = ratings.fold<double>(
                        0.0,
                            (acc, rating) => acc + (rating['rating'] as num).toDouble(),
                      );
                      double averageRating =
                      numOfRatings > 0 ? totalRating / numOfRatings : 0.0;

                      double? userRating;
                      for (var rating in ratings) {
                        if (rating['userId'] == user.uid) {
                          userRating = rating['rating'];
                          break;
                        }
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RatingBar(
                            initialRating: userRating ?? 5.0,
                            hasRated: userRating != null,
                            userRating: userRating ?? 0.0,
                            onRatingEnd: (rating) async {
                              setState(() {
                                currentRating = rating;
                              });

                              String response =
                              await FireStorePostsMethods().ratePost(
                                widget.postId,
                                user.uid,
                                rating,
                              );

                              if (response != 'success') {
                                if (mounted) {
                                  showSnackBar(context, response);
                                }
                              } else {
                                if (mounted) {
                                  showSnackBar(
                                      context, 'Rating submitted successfully');
                                  setState(() {});
                                }
                              }
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.comment_outlined,
                                      color: Color(0xFFd9d9d9)),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CommentsScreen(
                                        postId: widget.postId,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.send,
                                      color: Color(0xFFd9d9d9)),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => PostShare(
                                        currentUserId: user.uid,
                                        postId: widget.postId,
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RatingListScreen(
                                            postId: widget.postId),
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
                                      ),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
