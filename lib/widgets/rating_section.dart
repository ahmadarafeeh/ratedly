import 'package:flutter/material.dart';
import 'package:Ratedly/resources/posts_firestore_methods.dart';
import 'package:Ratedly/utils/utils.dart';
import 'package:Ratedly/widgets/flutter_rating_bar.dart';

class RatingSection extends StatefulWidget {
  final String postId;
  final String userId;
  final List<dynamic> ratings;
  final VoidCallback onRateUpdate;

  const RatingSection({
    Key? key,
    required this.postId,
    required this.userId,
    required this.ratings,
    required this.onRateUpdate,
  }) : super(key: key);

  @override
  State<RatingSection> createState() => _RatingSectionState();
}

class _RatingSectionState extends State<RatingSection> {
  double currentRating = 0;

  @override
  Widget build(BuildContext context) {
    double? userRating;
    for (var rating in widget.ratings) {
      if ((rating['userId'] as String) == widget.userId) {
        userRating = (rating['rating'] as num).toDouble();
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 1.5),
        RatingBar(
          initialRating: userRating ?? 5.0,
          hasRated: userRating != null,
          userRating: userRating ?? 0.0,
          onRatingEnd: (rating) async {
            setState(() => currentRating = rating);
            try {
              final response = await FireStorePostsMethods().ratePost(
                widget.postId,
                widget.userId,
                rating,
              );

              if (!mounted) return;

              if (response == 'success') {
                showSnackBar(context, 'Rating submitted successfully');
                widget.onRateUpdate();
              } else {
                showSnackBar(context, response);
              }
            } catch (e) {
              if (mounted) {
                showSnackBar(
                    context, 'Error submitting rating: ${e.toString()}');
              }
            } finally {
              if (mounted) {
                setState(() {});
              }
            }
          },
        ),
      ],
    );
  }
}
