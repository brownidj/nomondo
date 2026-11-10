import 'package:flutter/material.dart';

import '../models/restaurant.dart';

/// A small visual status light, with a larger touch target for pending reviews.
class RestaurantReviewIndicator extends StatelessWidget {
  const RestaurantReviewIndicator({
    super.key,
    required this.restaurant,
    required this.onReview,
  });

  final Restaurant restaurant;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final passed =
        restaurant.reviewStatus == 'passed' && !restaurant.needsReview;
    if (passed) {
      return Tooltip(
        message: 'Passed',
        child: Semantics(
          label: 'Review passed',
          image: true,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: _Led(color: Color(0xFF269344)),
          ),
        ),
      );
    }
    final percent = restaurant.confidence == null
        ? null
        : '${(restaurant.confidence! * 100).round()}%';
    return Tooltip(
      message:
          'Open review${percent == null ? '' : ' · research confidence $percent'}',
      child: TextButton(
        onPressed: onReview,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Semantics(
          label:
              'Needs review${percent == null ? '' : ', confidence $percent'}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _Led(color: Color(0xFFFFB300)),
              if (percent != null) ...[
                const SizedBox(width: 6),
                Text(percent, style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Led extends StatelessWidget {
  const _Led({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('review-led'),
    width: 12,
    height: 12,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-.4, -.5),
        colors: [
          Color.lerp(color, Colors.white, .65)!,
          color,
          Color.lerp(color, Colors.black, .25)!,
        ],
        stops: const [0, .55, 1],
      ),
      border: Border.all(
        color: Color.lerp(color, Colors.black, .25)!,
        width: .7,
      ),
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .25), blurRadius: 3),
      ],
    ),
  );
}
