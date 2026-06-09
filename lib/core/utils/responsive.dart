import 'package:flutter/widgets.dart';

/// Centralized layout breakpoints (logical pixels).
class Breakpoints {
  const Breakpoints._();

  /// Compact: < 600 (Phones in portrait)
  static const double compactMax = 600;

  /// Medium: 600 - 900 (Tablets, foldables, phones in landscape)
  static const double mediumMax = 900;

  /// Expanded: >= 900 (Large tablets, desktop screens)
  static const double expandedMin = 900;

  /// Compatibility constants
  static const double tablet = 600;
  static const double desktop = 1024;

  /// Comfortable max width for a single content column. On wider screens,
  /// the content is centered with side gutters instead of stretching full-bleed.
  static const double maxContent = 720;

  /// Comfortable max width for dual-column layouts on tablets and desktop monitors.
  static const double maxDoubleContent = 1200;

  /// Max width for floating bottom navigation bars on large tablets.
  static const double maxNav = 560;
}

/// Extension on [BuildContext] providing convenient access to screen dimensions
/// and responsive scaling helpers.
extension ResponsiveContext on BuildContext {
  /// The absolute width of the device screen.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// The absolute height of the device screen.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Whether the screen is compact (typically mobile phones in portrait).
  bool get isCompact => screenWidth < Breakpoints.compactMax;

  /// Whether the screen is medium-sized (large phones, foldables, or standard tablets).
  bool get isMedium =>
      screenWidth >= Breakpoints.compactMax &&
      screenWidth < Breakpoints.mediumMax;

  /// Whether the screen is expanded (large tablets, desktop monitors).
  bool get isExpanded => screenWidth >= Breakpoints.expandedMin;

  /// Tablet check (compatible helper).
  bool get isTablet => screenWidth >= Breakpoints.tablet;

  /// Desktop check (compatible helper).
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Helper to return responsive values depending on screen size.
  T responsiveValue<T>({
    required T compact,
    T? medium,
    T? expanded,
  }) {
    if (isExpanded) {
      return expanded ?? medium ?? compact;
    }
    if (isMedium) {
      return medium ?? compact;
    }
    return compact;
  }

  /// Scale spacing values proportionally depending on screen size.
  double spacing(double base) {
    return responsiveValue<double>(
      compact: base,
      medium: base * 1.25,
      expanded: base * 1.5,
    );
  }

  /// Scale font sizes proportionally depending on screen size.
  double scaleFont(double baseSize) {
    final scale = responsiveValue<double>(
      compact: 1.0,
      medium: 1.15,
      expanded: 1.25,
    );
    return baseSize * scale;
  }

  /// Scale an entire [TextStyle]'s font size proportionally.
  TextStyle responsiveTextStyle(TextStyle style) {
    if (style.fontSize == null) return style;
    return style.copyWith(fontSize: scaleFont(style.fontSize!));
  }
}

/// Centers [child] and caps its width at [maxWidth] on large screens.
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
