import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import 'contact_tooltip.dart';

String? _content(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty || text.toLowerCase() == 'not listed'
      ? null
      : text;
}

/// One cuisine link replaces the separate special-dish and notes buttons.
class CuisineDetails extends StatelessWidget {
  const CuisineDetails({super.key, required this.restaurant});
  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final cuisine = _content(restaurant.cuisine) ?? 'Not listed';
    final words = cuisine.split(RegExp(r'\s+'));
    final preview = words.length > 3
        ? '${words.take(3).join(' ')}\u2060…'
        : cuisine;
    return ContactTooltip(
      message: 'Click to see cuisine, special dishes and notes',
      child: TextButton(
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        onPressed: () => _showDetails(context, restaurant),
        child: Text(preview),
      ),
    );
  }
}

Widget _section(String label, String content, {String? icon}) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 6),
      SelectableText(content),
    ],
  ),
);

Future<void> _showDetails(BuildContext context, Restaurant restaurant) {
  final specialDish = _content(restaurant.specialDish);
  final notes = _content(restaurant.notes);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text('Cuisine — ${restaurant.name}'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('Cuisine', _content(restaurant.cuisine) ?? 'Not listed'),
            if (specialDish != null)
              _section('Special dishes', specialDish, icon: '🍽️'),
            if (notes != null) _section('Notes', notes, icon: '📝'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
