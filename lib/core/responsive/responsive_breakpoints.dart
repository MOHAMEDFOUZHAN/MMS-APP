import 'package:flutter/material.dart';

class ResponsiveBreakpoints {
  static const double mobile = 600.0;
  static const double smallTablet = 900.0;
  static const double tablet = 1200.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide < mobile;

  static bool isSmallTablet(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return shortest >= mobile && shortest < smallTablet;
  }

  static bool isTablet(BuildContext context) {
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    return shortest >= smallTablet && shortest < tablet;
  }

  static bool isLargeTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= tablet;

  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= mobile;

  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tablet) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= ResponsiveBreakpoints.mobile) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
