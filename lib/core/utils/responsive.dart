import 'package:flutter/widgets.dart';

/// Layout breakpoints (logical pixels). Phone-first; tablet/desktop only widen.
class Breakpoints {
  const Breakpoints._();

  /// At/above this width we treat the device as a tablet.
  static const double tablet = 600;

  /// At/above this width we treat the device as desktop / large iPad.
  static const double desktop = 1024;

  /// Comfortable max width for a single content column. On wider screens the
  /// content is centered with side gutters instead of stretching full-bleed.
  static const double maxContent = 720;

  /// A slightly wider cap for the floating bottom nav so it doesn't stretch
  /// across an entire iPad.
  static const double maxNav = 560;
}

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isTablet => screenWidth >= Breakpoints.tablet;
  bool get isDesktop => screenWidth >= Breakpoints.desktop;
}

/// Centers [child] and caps its width at [maxWidth] on large screens.
///
/// On phones (width below the cap) it's a transparent pass-through, so the
/// phone layout is unchanged. On tablets/iPads/desktop the content is centered
/// with even side gutters instead of stretching edge-to-edge.
///
/// [heightFactor] is forwarded to the underlying [Center]. Leave it null for
/// content that should fill the available height (scroll views). Set it to 1
/// when the widget must hug its child's height (e.g. a bottom nav bar), so the
/// centering doesn't expand vertically and float the child mid-screen.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = Breakpoints.maxContent,
    this.heightFactor,
  });

  final Widget child;
  final double maxWidth;
  final double? heightFactor;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: heightFactor,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
