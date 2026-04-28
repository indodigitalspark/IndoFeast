import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56, this.showLabel = false});

  final double size;
  final bool showLabel;

  String _assetPath(Brightness brightness) {
    return brightness == Brightness.dark
        ? 'assets/images/indofeast_logo.svg'
        : 'assets/images/indofeast_logo_orange.svg';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final logo = SvgPicture.asset(
      _assetPath(brightness),
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticsLabel: 'IndoFeast logo',
    );

    if (!showLabel) {
      return logo;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 12),
        Text(
          'IndoFeast',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
