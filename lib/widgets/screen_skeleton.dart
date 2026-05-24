import 'package:flutter/material.dart';

/// Universal skeleton UI untuk loading screen.
///
/// Dipakai untuk mengganti spinner saat data masih dimuat.
class ScreenSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final int lineCount;
  final double lineHeight;
  final BorderRadiusGeometry borderRadius;
  final bool showTitle;

  const ScreenSkeleton({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.lineCount = 6,
    this.lineHeight = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey[300];
    final highlight = theme.brightness == Brightness.dark ? Colors.white24 : Colors.grey[100];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle) ...[
            _ShimmerBar(
              height: 20,
              borderRadius: borderRadius,
              width: MediaQuery.of(context).size.width * 0.55,
              base: base!,
              highlight: highlight!,
            ),
            const SizedBox(height: 16),
          ],
          for (int i = 0; i < lineCount; i++) ...[
            _ShimmerBar(
              height: lineHeight,
              borderRadius: borderRadius,
              width: i == 0
                  ? MediaQuery.of(context).size.width * 0.85
                  : i % 3 == 0
                      ? MediaQuery.of(context).size.width * 0.7
                      : MediaQuery.of(context).size.width * 0.95,
              base: base!,
              highlight: highlight!,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class ScreenListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double padding;
  final BorderRadiusGeometry borderRadius;

  const ScreenListSkeleton({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 84,
    this.padding = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.brightness == Brightness.dark ? Colors.white12 : Colors.grey[300];
    final highlight = theme.brightness == Brightness.dark ? Colors.white24 : Colors.grey[100];

    return ListView.separated(
      padding: EdgeInsets.all(padding),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Container(
          height: itemHeight,
          decoration: BoxDecoration(
            color: base,
            borderRadius: borderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShimmerBar(
                  height: 14,
                  borderRadius: borderRadius,
                  width: MediaQuery.of(context).size.width * 0.55,
                  base: base!,
                  highlight: highlight!,
                ),
                const SizedBox(height: 10),
                _ShimmerBar(
                  height: 12,
                  borderRadius: borderRadius,
                  width: MediaQuery.of(context).size.width * (index % 2 == 0 ? 0.8 : 0.65),
                  base: base,
                  highlight: highlight!,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBar extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadiusGeometry borderRadius;
  final Color base;
  final Color highlight;

  const _ShimmerBar({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.base,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final left = (value - 0.5) * 0.8;
          final right = left + 0.35;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [base, highlight, base],
                stops: [
                  (left).clamp(0.0, 1.0),
                  (value).clamp(0.0, 1.0),
                  (right).clamp(0.0, 1.0),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

