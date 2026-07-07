import 'package:flutter/material.dart';

import '../theme/windows_theme.dart';

/// Flat bordered panel (Windows-style, no Material elevation).
class WinPanel extends StatelessWidget {
  const WinPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.backgroundColor = WindowsTheme.surface,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: WindowsTheme.border),
      ),
      child: child,
    );
  }
}
