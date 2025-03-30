import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/utils/colors.dart';
import 'package:helloworld/utils/global_variable.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:helloworld/providers/user_provider.dart';
import 'package:helloworld/resources/notification_read.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({Key? key}) : super(key: key);

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _page = 0;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  void navigationTapped(int page) async {
    if (page == 2) {
      // Notification page index
      final user = Provider.of<UserProvider>(context, listen: false).user;
      if (user != null) {
        await NotificationService.markNotificationsAsRead(user.uid);
      }
    }
    pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).user;

    // Enhanced null check including user ID validation.
    if (user?.uid == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentUserId = user!.uid; // Guaranteed non-null

    return Scaffold(
      body: PageView(
        controller: pageController,
        onPageChanged: onPageChanged,
        children: homeScreenItems,
      ),
      bottomNavigationBar: CupertinoTabBar(
        backgroundColor: mobileBackgroundColor,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              Icons.home,
              color: (_page == 0) ? primaryColor : secondaryColor,
            ),
            label: '',
            backgroundColor: primaryColor,
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.search,
              color: (_page == 1) ? primaryColor : secondaryColor,
            ),
            label: '',
            backgroundColor: primaryColor,
          ),
          BottomNavigationBarItem(
            // Use our custom widget for notification count.
            icon: NotificationBadgeIcon(
              currentUserId: currentUserId,
              currentPage: _page,
              pageIndex: 2,
            ),
            label: '',
            backgroundColor: primaryColor,
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person,
              color: (_page == 3) ? primaryColor : secondaryColor,
            ),
            label: '',
            backgroundColor: primaryColor,
          ),
        ],
        onTap: navigationTapped,
        currentIndex: _page,
      ),
    );
  }
}

class NotificationBadgeIcon extends StatelessWidget {
  final String currentUserId;
  final int currentPage;
  final int pageIndex;

  const NotificationBadgeIcon({
    Key? key,
    required this.currentUserId,
    required this.currentPage,
    required this.pageIndex,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('targetUserId', isEqualTo: currentUserId)
          .where('isRead', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        // Get unread notifications count.
        final count = snapshot.data?.docs.length ?? 0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.favorite,
              color: (currentPage == pageIndex) ? primaryColor : secondaryColor,
            ),
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
