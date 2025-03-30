import 'package:flutter/material.dart';
import 'package:helloworld/resources/posts_firestore_methods.dart';
import 'package:helloworld/utils/utils.dart';
import 'package:helloworld/widgets/flutter_rating_bar.dart';

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

  void _handleRateUpdate() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double? userRating;
    for (var rating in widget.ratings) {
      if ((rating['userId'] as String) == widget.userId) {
        userRating = rating['rating'] as double?;
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

              if (response == 'success') {
                showSnackBar(context, 'Rating submitted successfully');
                widget.onRateUpdate(); // Trigger parent update
              } else {
                showSnackBar(context, response);
              }
            } catch (e) {
              showSnackBar(context, 'Error submitting rating: ${e.toString()}');
            } finally {
              setState(() {});
            }
          },
        ),
      ],
    );
  }
}
