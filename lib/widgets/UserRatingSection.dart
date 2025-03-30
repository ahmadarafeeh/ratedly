import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:helloworld/resources/profile_firestore_methods.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/widgets/flutter_rating_bar.dart';

class UserRatingSection extends StatefulWidget {
  final String userId;
  final String raterUserId;
  final VoidCallback? onRatingSubmitted;

  const UserRatingSection({
    Key? key,
    required this.userId,
    required this.raterUserId,
    this.onRatingSubmitted,
  }) : super(key: key);

  @override
  State<UserRatingSection> createState() => _UserRatingSectionState();
}

class _UserRatingSectionState extends State<UserRatingSection> {
  double currentRating = 0;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final ratings = (userData['ratings'] as List?) ?? [];
        double? userRating;

        for (var rating in ratings) {
          if (rating['raterUserId'] == widget.raterUserId) {
            userRating = rating['rating'] as double?;
            break;
          }
        }

        return RatingBar(
          initialRating: userRating ?? 0.0,
          hasRated: userRating != null,
          userRating: userRating ?? 0.0,
          onRatingEnd: (rating) async {
            final result = await FireStoreProfileMethods().rateUser(
              widget.userId,
              widget.raterUserId,
              rating,
            );

            if (result == 'success') {
              widget.onRatingSubmitted?.call();
            } else {
              showSnackBar(context, result);
            }
          },
        );
      },
    );
  }
}
