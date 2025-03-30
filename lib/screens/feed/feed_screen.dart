import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:helloworld/utils/colors.dart';
import 'package:helloworld/utils/global_variable.dart';
import 'package:helloworld/screens/feed/post_card.dart';
import 'package:helloworld/widgets/feedmessages.dart';
import 'package:helloworld/resources/messages_firestore_methods.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/resources/block_firestore_methods.dart';
import 'package:flutter/foundation.dart';
import 'package:helloworld/screens/MessagingScreen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  int _selectedTab = 0;
  final ScrollController _scrollController = ScrollController();

  void _handleRateUpdate() {
    final double? currentPosition =
        _scrollController.hasClients ? _scrollController.position.pixels : null;

    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (currentPosition != null && _scrollController.hasClients) {
          _scrollController.jumpTo(currentPosition);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: _buildAppBar(width),
      body: _buildFeedBody(width),
    );
  }

  Widget _buildTab(String text, int index) {
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _selectedTab == index
                  ? const Color(0xFFd9d9d9)
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Text(
          text,
          style: TextStyle(
            color: const Color(0xFFd9d9d9),
            fontWeight: FontWeight.w600,
            fontSize: 16,
            fontFamily: 'Montserrat',
          ),
        ),
      ),
    );
  }

  AppBar? _buildAppBar(double width) {
    return width > webScreenSize
        ? null
        : AppBar(
            backgroundColor: const Color(0xFF121212),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('Following', 0),
                const SizedBox(width: 20),
                _buildTab('For You', 1),
              ],
            ),
            centerTitle: true,
            actions: [_buildMessageButton()],
          );
  }

  Widget _buildMessageButton() {
    return StreamBuilder<int>(
      stream: FireStoreMessagesMethods().getTotalUnreadCount(currentUserId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              onPressed: () => _navigateToMessages(),
              icon: const Icon(Icons.message, color: Color(0xFFd9d9d9)),
            ),
            if (count > 0) _buildUnreadCountBadge(count),
          ],
        );
      },
    );
  }

  void _navigateToMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedMessages(currentUserId: currentUserId),
      ),
    );
  }

  Widget _buildUnreadCountBadge(int count) {
    return Positioned(
      right: 8,
      top: 8,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: Color(0xFF333333),
          shape: BoxShape.circle,
        ),
        child: Text(
          count.toString(),
          style: const TextStyle(
            color: Color(0xFFd9d9d9),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
      ),
    );
  }

  Future<List<String>> _getBlockedByUsers(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('blockedUsers', arrayContains: userId)
          .get();
      return querySnapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      debugPrint("Error fetching users who blocked current user: $e");
      return [];
    }
  }

  Widget _buildFeedBody(double width) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (userSnapshot.hasError) {
                return Center(child: Text('Error: ${userSnapshot.error}'));
              }

              final userData = userSnapshot.data?.data();
              if (userData == null) {
                return const Center(child: Text('User data not found'));
              }

              final blockedUsers = List<String>.from(
                  userData['blockedUsers'] as List<dynamic>? ?? []);
              final following = List<dynamic>.from(
                  userData['following'] as List<dynamic>? ?? []);
              final region = userData['region'] as String? ?? '';

              return FutureBuilder<List<String>>(
                future: _getBlockedByUsers(currentUserId),
                builder: (context, blockedBySnapshot) {
                  if (blockedBySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final blockedByUsers = blockedBySnapshot.data ?? [];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .snapshots(),
                    builder: (context, postSnapshot) {
                      if (postSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (postSnapshot.hasError) {
                        return Center(
                            child: Text('Error: ${postSnapshot.error}'));
                      }

                      final posts = postSnapshot.data?.docs ?? [];

                      return _buildPostList(
                        posts,
                        blockedUsers,
                        blockedByUsers,
                        width,
                        following,
                        region,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _getUserRegionGroup(String region) {
    const regionGroups = [
      ['Middle East', 'Asia'],
      ['North America', 'South America'],
      ['Africa'],
      ['Europe', 'United States'],
    ];
    for (var group in regionGroups) {
      if (group.contains(region)) {
        return group;
      }
    }
    return [region];
  }

  Future<Map<String, bool>> _fetchUserPrivacyStatus(Set<String> userIds) async {
    if (userIds.isEmpty) return {};

    final userIdList = userIds.toList();
    final futures = <Future<QuerySnapshot>>[];

    for (var i = 0; i < userIdList.length; i += 10) {
      final batch = userIdList.sublist(
        i,
        i + 10 > userIdList.length ? userIdList.length : i + 10,
      );
      futures.add(
        FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batch)
            .get(),
      );
    }

    try {
      final results = await Future.wait(futures);
      final privacyMap = <String, bool>{};

      for (final result in results) {
        for (final doc in result.docs) {
          privacyMap[doc.id] = doc.get('isPrivate') as bool? ?? false;
        }
      }

      return privacyMap;
    } catch (e) {
      debugPrint('Error fetching privacy status: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _getCurrentUserDetails() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      return userDoc.data() ?? {};
    } catch (e) {
      debugPrint('Error fetching user details: $e');
      return {};
    }
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterForYouPosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    List<dynamic> following,
    List<String> userRegionGroup,
    String currentUserGender,
    int currentUserAge,
    List<String> viewedPosts,
  ) {
    final postScores =
        <MapEntry<QueryDocumentSnapshot<Map<String, dynamic>>, double>>[];
    final now = DateTime.now();

    debugPrint('\n=== STARTING POST SCORING ===');
    debugPrint('Current user gender: $currentUserGender, age: $currentUserAge');
    debugPrint('User region group: $userRegionGroup');
    debugPrint('Already viewed posts: ${viewedPosts.length}');

    for (final post in posts) {
      final postData = post.data();
      final postUid = postData['uid'] as String?;
      final postId = postData['postId'] as String? ?? 'unknown-post';

      if (postUid == null) {
        debugPrint('\nPost $postId SKIPPED: Missing user ID');
        continue;
      }

      // Initial filtering checks
      if (following.any((entry) =>
          entry is Map<String, dynamic> && entry['userId'] == postUid)) {
        debugPrint('\nPost $postId SKIPPED: User is being followed');
        continue;
      }

      final postRegion = postData['region'] as String? ?? '';
      if (!userRegionGroup.contains(postRegion)) {
        debugPrint(
            '\nPost $postId SKIPPED: Region $postRegion not in $userRegionGroup');
        continue;
      }

      debugPrint('\nScoring post $postId');
      double priorityScore = 0;
      final breakdown = <String>[];

      // 1. Newness Score
      final isNew = !viewedPosts.contains(postId);
      if (isNew) {
        priorityScore += 15;
        breakdown.add('Newness: +15');
      } else {
        breakdown.add('Newness: 0 (already viewed)');
      }

      // 2. Gender Difference
      final postOwnerGender = postData['gender'] as String? ?? '';
      if (postOwnerGender.toLowerCase() != currentUserGender.toLowerCase()) {
        priorityScore += 15;
        breakdown.add(
            'Gender difference: +15 ($postOwnerGender vs $currentUserGender)');
      } else {
        breakdown.add('Gender difference: 0 (same gender)');
      }

      // 3. Rating Score
      final postRating =
          _calculateAverageRating(postData['rate'] as List<dynamic>? ?? []);
      if (postRating >= 7.8) {
        final ratingPoints = _mapRange(postRating, 7.8, 10.0, 0, 25);
        priorityScore += ratingPoints;
        breakdown
            .add('Rating: +${ratingPoints.toStringAsFixed(1)} ($postRating)');
      } else {
        breakdown.add('Rating: 0 (below 7.8 threshold)');
      }

      // 4. Age Difference
      final postOwnerAge = postData['age'] as int? ?? 0;
      final ageDifference = postOwnerAge - currentUserAge;
      if (ageDifference >= 0 && ageDifference <= 10) {
        final agePoints = _mapRange(ageDifference.toDouble(), 0, 10, 15, 0);
        priorityScore += agePoints;
        breakdown.add(
            'Age difference: +${agePoints.toStringAsFixed(1)} ($ageDifference years)');
      } else {
        breakdown.add('Age difference: 0 (diff: $ageDifference)');
      }

      // 5. Voter Count
      final numVoters = (postData['rate'] as List<dynamic>? ?? []).length;
      final voterPoints =
          _mapRange(numVoters.toDouble().clamp(0, 100), 0, 100, 0, 30);
      priorityScore += voterPoints;
      breakdown.add(
          'Voters: +${voterPoints.toStringAsFixed(1)} ($numVoters voters)');

      // 6. Time Since Posted
      final postDate =
          (postData['datePublished'] as Timestamp?)?.toDate() ?? DateTime.now();
      final daysSincePosted = now.difference(postDate).inDays;
      if (daysSincePosted <= 7) {
        final clampedDays = daysSincePosted.clamp(1, 7);
        final timePoints = _mapRange(clampedDays.toDouble(), 1, 7, 10, 0);
        priorityScore += timePoints;
        breakdown.add(
            'Freshness: +${timePoints.toStringAsFixed(1)} ($daysSincePosted days old)');
      } else {
        breakdown.add('Freshness: 0 (too old: $daysSincePosted days)');
      }

      // 7. Comment Score
      final commentCount = postData['commentsCount'] as int? ?? 0;
      if (commentCount >= 5) {
        final commentPoints =
            _mapRange(commentCount.toDouble().clamp(5, 100), 5, 100, 5, 20);
        priorityScore += commentPoints;
        breakdown.add(
            'Comments: +${commentPoints.toStringAsFixed(1)} ($commentCount comments)');
      } else {
        breakdown.add('Comments: 0 (only $commentCount comments)');
      }

      // Add final score
      breakdown.add('TOTAL SCORE: ${priorityScore.toStringAsFixed(1)}');
      debugPrint(breakdown.join('\n'));

      postScores.add(MapEntry(post, priorityScore));
    }

    debugPrint('\n=== FINAL POST RANKING ===');
    postScores.sort((a, b) => b.value.compareTo(a.value));

    // Print top 20 posts
    postScores.take(20).forEach((entry) {
      final postId = entry.key.data()['postId'] as String? ?? 'unknown-post';
      debugPrint('Post $postId: ${entry.value.toStringAsFixed(1)} points');
    });

    final prioritized = postScores.where((e) => e.value >= 50).toList();
    final others = postScores.where((e) => e.value < 50).toList();

    debugPrint('\n=== FINAL CATEGORIZATION ===');
    debugPrint('Prioritized posts (>=50 points): ${prioritized.length}');
    debugPrint('Other posts (<50 points): ${others.length}');
    debugPrint('Total considered posts: ${postScores.length}');
    debugPrint('Total filtered posts: ${prioritized.length + others.length}');

    return [
      ...prioritized.map((e) => e.key),
      ...others.map((e) => e.key),
    ];
  }

  double _calculateAverageRating(List<dynamic> ratings) {
    if (ratings.isEmpty) return 0.0;
    return ratings.fold<double>(
            0.0,
            (sum, r) =>
                sum +
                ((r is Map<String, dynamic> ? r['rating'] as double? : null) ??
                    0.0)) /
        ratings.length;
  }

  double _mapRange(
      double value, double inMin, double inMax, double outMin, double outMax) {
    return (value - inMin) * (outMax - outMin) / (inMax - inMin) + outMin;
  }

  Widget _buildEmptyFollowingMessage(double width) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, size: 64, color: const Color(0xFF444444)),
            const SizedBox(height: 20),
            const Text(
              'Your Following Feed is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFd9d9d9),
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Follow interesting users to see their posts here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFFd9d9d9),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsListView(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    double width,
  ) {
    return ListView.builder(
      controller: _scrollController,
      key: const PageStorageKey('feedListView'),
      itemCount: posts.length,
      itemBuilder: (ctx, index) {
        final post = posts[index];
        return FutureBuilder<bool>(
          future: FirestoreBlockMethods().isMutuallyBlocked(
            currentUserId,
            post['uid'],
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data!) {
              return const BlockedContentMessage(
                message: 'Post unavailable due to blocking',
              );
            }

            return Container(
              margin: EdgeInsets.symmetric(
                horizontal: width > webScreenSize ? width * 0.3 : 0,
                vertical: width > webScreenSize ? 15 : 0,
              ),
              child: PostCard(
                snap: post.data(),
                onRateUpdate: _handleRateUpdate,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    List<String> blockedUsers,
    List<String> blockedByUsers,
    double width,
    List<dynamic> following,
    String region,
  ) {
    final filteredPosts = posts.where((post) {
      final postUid = post.data()['uid'] as String?;
      return postUid != null &&
          !blockedUsers.contains(postUid) &&
          !blockedByUsers.contains(postUid) &&
          postUid != currentUserId;
    }).toList();

    if (_selectedTab == 0) {
      final followingPosts = filteredPosts.where((post) {
        final postUid = post.data()['uid'] as String?;
        return postUid != null &&
            following.any((entry) =>
                entry is Map<String, dynamic> && entry['userId'] == postUid);
      }).toList();

      if (followingPosts.isEmpty) {
        return _buildEmptyFollowingMessage(width);
      }
      return _buildPostsListView(followingPosts, width);
    } else {
      final userRegionGroup = _getUserRegionGroup(region);

      return FutureBuilder<Map<String, dynamic>>(
        future: _getCurrentUserDetails(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnapshot.data ?? {};
          final currentUserGender = userData['gender'] as String? ?? '';
          final currentUserAge = userData['age'] as int? ?? 0;

          return FutureBuilder<List<String>>(
            future: FireStorePostsMethods().getViewedPostIds(currentUserId),
            builder: (context, viewedPostsSnapshot) {
              if (viewedPostsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final viewedPosts = viewedPostsSnapshot.data ?? [];
              final forYouPosts = _filterForYouPosts(
                filteredPosts,
                following,
                userRegionGroup,
                currentUserGender,
                currentUserAge,
                viewedPosts,
              );

              final userIds = forYouPosts
                  .map((post) => post.data()['uid'] as String?)
                  .whereType<String>()
                  .toSet();

              return FutureBuilder<Map<String, bool>>(
                future: _fetchUserPrivacyStatus(userIds),
                builder: (context, privacySnapshot) {
                  if (privacySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final privacyMap = privacySnapshot.data ?? {};
                  final filteredForYouPosts = forYouPosts.where((post) {
                    final uid = post.data()['uid'] as String?;
                    return uid != null && !(privacyMap[uid] ?? false);
                  }).toList();

                  return _buildPostsListView(filteredForYouPosts, width);
                },
              );
            },
          );
        },
      );
    }
  }
}
