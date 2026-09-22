import 'package:flutter/material.dart';

/// A slightly tilted, borderless Kipt logo "stamp" shown in the top-right of
/// an item card when the item is marked as a favorite.
class FavoriteSeal extends StatelessWidget {
  final double size;

  const FavoriteSeal({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.12,
      child: SizedBox(
        width: size,
        height: size,
        child: Image.asset(
          Theme.of(context).brightness == Brightness.dark
              ? 'assets/Kipt_for_darktheme.png'
              : 'assets/Kipt_for_lighttheme.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.star_rounded,
            size: size * 0.7,
            color: Theme.of(context).colorScheme.tertiary,
          ),
        ),
      ),
    );
  }
}
